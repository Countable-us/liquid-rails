require "spec_helper"

RSpec.describe Liquid::Rails::TemplateCache do
  it "returns a cached value and evicts the least recently used entry" do
    cache = described_class.new(max_size: 2)

    expect(cache.fetch(:one) { Object.new }).to equal(cache.fetch(:one) { Object.new })
    cache.fetch(:two) { :two }
    cache.fetch(:one) { :replacement }
    cache.fetch(:three) { :three }

    expect(cache.fetch(:two) { :reloaded }).to eq(:reloaded)
    expect(cache.size).to eq(2)
  end

  it "is safe under concurrent fetches" do
    cache = described_class.new(max_size: 10)
    threads = 20.times.map { |number| Thread.new { cache.fetch(number % 3) { number % 3 } } }

    expect(threads.map(&:value).sort.uniq).to eq([0, 1, 2])
    expect(cache.size).to eq(3)
  end

  it "caches falsey values" do
    cache = described_class.new(max_size: 1)

    expect(cache.fetch(:false_value) { false }).to be(false)
    expect(cache.fetch(:false_value) { :replacement }).to be(false)
  end
end
