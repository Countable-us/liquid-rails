require "spec_helper"

RSpec.describe Liquid::Rails::FileSystem do
  it "uses LookupContext#find_all with public arguments" do
    template = instance_double(ActionView::Template, source: "partial source")
    lookup_context = instance_double(ActionView::LookupContext)
    view = instance_double(
      ActionView::Base,
      controller_path: "pages",
      locale: :en,
      formats: [:html],
      lookup_context: lookup_context
    )
    allow(lookup_context).to receive(:find_all).with(
      "card", ["pages"], true, [],
      locale: [:en], formats: [:html], variants: [], handlers: [:liquid]
    ).and_return([template])

    expect(described_class.new(view).read_template_file("card")).to eq("partial source")
  end
end
