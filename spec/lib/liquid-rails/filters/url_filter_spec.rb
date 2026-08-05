require "spec_helper"

RSpec.describe Liquid::Rails::UrlFilter do
  it "keeps URL helpers generic" do
    expect(described_class.instance_methods(false)).to contain_exactly(
      :current_page?, :link_to, :link_to_unless_current, :mail_to, :url_for
    )
  end

  it "normalizes URL options before forwarding them to the view" do
    view = instance_double(ActionView::Base)
    filter = Class.new { include Liquid::Rails::UrlFilter }.new
    context = Liquid::Context.new({}, {}, {view: view})
    filter.instance_variable_set(:@context, context)
    allow(view).to receive(:url_for).with({locale: "en", only_path: true}).and_return("/en")

    expect(filter.url_for({"locale" => "en", "only_path" => true})).to eq("/en")
  end
end
