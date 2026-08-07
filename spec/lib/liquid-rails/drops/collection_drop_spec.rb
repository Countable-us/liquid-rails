require "spec_helper"

class QuerySpy
  include Enumerable

  attr_reader :each_calls, :slice_calls

  def initialize(items)
    @items = items
    @each_calls = 0
    @slice_calls = 0
  end

  def each(&block)
    @each_calls += 1
    @items.each(&block)
  end

  def slice(range)
    @slice_calls += 1
    @items.slice(range)
  end

  def length
    @items.length
  end
end

RSpec.describe Liquid::Rails::CollectionDrop do
  it "infers conventional item drops without requiring Droppable on the resources" do
    collection = described_class.new([ConventionOnly.new])

    expect(collection.first).to be_instance_of(ConventionOnlyDrop)
  end

  it "supports Liquid iteration without eager mapping" do
    source = QuerySpy.new([Profile.new(name: "One"), Profile.new(name: "Two")])
    drop = described_class.new(source, with: "ProfileDrop", current_user: "viewer")

    rendered = Liquid::Template
      .parse("{% for item in items %}{{ item.name }}{% endfor %}", environment: Liquid::Rails.environment)
      .render!("items" => drop)

    expect(rendered).to eq("OneTwo")
    expect(source.each_calls).to eq(1)
  end

  it "loads only the requested Liquid loop slice" do
    source = QuerySpy.new([Profile.new(name: "One"), Profile.new(name: "Two")])
    drop = described_class.new(source, with: "ProfileDrop")

    rendered = Liquid::Template
      .parse("{% for item in items limit: 1 %}{{ item.name }}{% endfor %}", environment: Liquid::Rails.environment)
      .render!("items" => drop)

    expect(rendered).to eq("One")
    expect(source.each_calls).to eq(0)
    expect(source.slice_calls).to eq(1)
  end

  it "renders every documented Liquid collection property" do
    drop = described_class.new(
      [
        Profile.new(name: "One"),
        Profile.new(name: "Two"),
        Profile.new(name: "Three")
      ],
      with: "ProfileDrop"
    ).page(1).per(2)

    rendered = Liquid::Template
      .parse(<<~LIQUID, environment: Liquid::Rails.environment)
        {{ items[1].name }}|
        {{ items.first.name }}|
        {{ items.last.name }}|
        {{ items.count }}|
        {{ items.size }}|
        {{ items.length }}|
        {{ items.empty? }}|
        {{ items.total_count }}|
        {{ items.total_pages }}
      LIQUID
      .render!("items" => drop)

    expect(rendered.lines.map(&:strip).join).to eq("Two|One|Two|2|2|2|false|3|2")
  end

  it "slices paginated arrays for Liquid loop limits and offsets" do
    drop = described_class.new(
      [
        Profile.new(name: "One"),
        Profile.new(name: "Two"),
        Profile.new(name: "Three"),
        Profile.new(name: "Four")
      ],
      with: "ProfileDrop"
    ).page(1).per(3)

    rendered = Liquid::Template
      .parse(<<~LIQUID, environment: Liquid::Rails.environment)
        {% for item in items limit: 2 %}{{ item.name }}{% endfor %}|
        {% for item in items offset: 1 %}{{ item.name }}{% endfor %}
      LIQUID
      .render!("items" => drop)

    expect(rendered.lines.map(&:strip).join).to eq("OneTwo|TwoThree")
  end

  it "renders declared collection scopes" do
    drop = CommentsDrop.new(PaginatedComments.new([Comment.new(body: "Approved")]))

    rendered = Liquid::Template
      .parse("{{ items.approved.first.body }}", environment: Liquid::Rails.environment)
      .render!("items" => drop)

    expect(rendered).to eq("Approved")
  end

  it "does not dispatch arbitrary Ruby methods" do
    drop = described_class.new([Profile.new(name: "One")], with: "ProfileDrop")

    expect(drop["object_id"]).to be_nil
    expect(drop["to_json"]).to be_nil
  end

  it "exposes the source only through the Ruby class API" do
    source = [Profile.new(name: "One")]
    drop = described_class.new(source, with: "ProfileDrop")

    expect(described_class.unwrap(drop)).to equal(source)
    expect(drop["objects"]).to be_nil
  end

  it "raises Ruby ArgumentError when unwrapping a non-collection" do
    expect { described_class.unwrap(Object.new) }
      .to raise_error(::ArgumentError, "expected CollectionDrop")
  end

  it "raises Ruby ArgumentError when a declared scope is missing on the source" do
    collection = CommentsDrop.new([])

    expect { collection.approved }
      .to raise_error(::ArgumentError, /doesn't define scope/)
  end

  it "paginates arrays without exposing their methods to Liquid" do
    drop = described_class.new(
      [Profile.new(name: "One"), Profile.new(name: "Two")],
      with: "ProfileDrop"
    )

    page = drop.page(2).per(1)

    expect(page.first.name).to eq("Two")
    expect(page.total_pages).to eq(2)
  end
end
