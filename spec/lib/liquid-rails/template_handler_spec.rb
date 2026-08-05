require 'spec_helper'

describe 'Request', type: :feature do
  describe 'layout' do
    context 'render without layout' do
      it 'renders with liquid template' do
        visit '/'

        expect(page.body).to eq('Liquid on Rails')
      end

      it 'sets content_type as html by default' do
        visit '/'

        expect(page.response_headers['Content-Type']).to eq('text/html; charset=utf-8')
      end
    end

    context 'render with layout' do
      it 'renders with layout' do
        visit '/index_with_layout'

        expect(page.body).to eq("Application Layout\nLiquid on Rails")
      end
    end
  end

  describe 'partial' do
    context 'render with partial' do
      it 'no full path for the current controller' do
        visit '/index_partial'

        expect(page.body).to eq("Application Layout\nLiquid on Rails\n\nHome Partial\nShared Partial")
      end

      it 'full path' do
        visit '/index_partial_with_full_path'

        expect(page.body).to eq("Application Layout\nLiquid on Rails\n\nHome Partial\nShared Partial")
      end

      it 'respects namespace of original template for partials path' do
        visit '/foospace/bar/index_partial'

        expect(page.body.strip).to eq("Foospace::BarController\n\nBar Partial")
      end
    end
  end

  describe 'filter' do
    context 'render with filter' do
      it 'renders with helper' do
        visit '/index_with_filter'

        expect(page.body).to eq("Application Layout\nLiquid on Rails\nThis...")
      end

      it 'renders with helper' do
        visit '/index_without_filter'

        expect(page.body).to eq("Application Layout\nLiquid on Rails\nThis is a long section of text")
      end
    end
  end

  describe 'erb' do
    context 'render html within an erb template' do
      it 'does not escape the html' do
        visit '/erb_with_html_liquid_partial'

        expect(page.body.strip).to eq("Application Layout\n<p>Partial Content</p>")
      end
    end
  end

  describe 'content_type' do
    context 'render RSS with an ERB template' do
      it 'returns an rss content type' do
        visit '/index_with_rss.rss'

        expect(page.response_headers['Content-Type']).to eq('application/rss+xml; charset=utf-8')
      end
    end
  end

  describe 'custom actionview resolver' do
    before do
      ApplicationController.class_eval do
        before_action :prepend_view_path_if_param_present

        def prepend_view_path_if_param_present
          prepend_view_path Rails.root.join('vendor/theme') if params[:prepend_view_path]
        end
      end
    end

    it 'no full path for the current controller' do
      visit '/index_partial?prepend_view_path=true'

      expect(page.body).to eq("Application Layout\nLiquid on Rails\n\nVendor Theme Home Partial\n\nVendor Theme Shared Partial\n")
    end

    it 'full path' do
      visit '/index_partial_with_full_path?prepend_view_path=true'

      expect(page.body).to eq("Application Layout\nLiquid on Rails\n\nVendor Theme Home Partial\n\nVendor Theme Shared Partial\n")
    end

    it 'respects namespace of original template for partials path' do
      visit '/foospace/bar/index_partial?prepend_view_path=true'

      expect(page.body.strip).to eq("Foospace::BarController\n\nVendor Theme Bar Partial")
    end
  end
end

class TemplateHandlerSpecController
  attr_accessor :liquid_assigns, :liquid_filters

  def initialize(assigns = {}, filters = [])
    @liquid_assigns = assigns
    @liquid_filters = filters
  end
end

class TemplateHandlerSpecView
  attr_reader :assigns, :controller, :liquid_registers, :lookup_context, :site_id

  def initialize(controller:, assigns: {}, liquid_registers: {}, site_id: nil)
    @assigns = assigns
    @controller = controller
    @liquid_registers = liquid_registers
    @lookup_context = Struct.new(:locale).new(:en)
    @site_id = site_id
  end

  def content_for?(_name)
    false
  end

  def content_for(_name)
    nil
  end

end

module TemplateHandlerSpecErrorFilter
  def raise_liquid_error(_input)
    raise Liquid::Error, "expected render failure"
  end
end

class TemplateHandlerSpecRegisterProbeTag < Liquid::Tag
  class << self
    attr_accessor :captures
  end

  def render(context)
    self.class.captures << [context.registers.static.object_id, context.registers[:resources].object_id]
    ""
  end
end

RSpec.describe Liquid::Rails::TemplateHandler do
  let(:configuration) { Liquid::Rails.configuration }
  let(:controller) { TemplateHandlerSpecController.new }
  let(:view) { TemplateHandlerSpecView.new(controller: controller) }
  let(:handler) { described_class.new(view) }

  before do
    configuration.cache_namespace = nil
    configuration.cache_size = 1_000
    configuration.render_errors = :raise
    Liquid::Rails.reset_template_cache! if Liquid::Rails.respond_to?(:reset_template_cache!)
  end

  after do
    configuration.cache_namespace = nil
    configuration.cache_size = 1_000
    configuration.render_errors = :raise
    Liquid::Rails.reset_template_cache! if Liquid::Rails.respond_to?(:reset_template_cache!)
  end

  it "does not mutate controller assigns or local assigns" do
    controller_assigns = {"title" => "Original"}
    local_assigns = {subtitle: "Local"}
    controller.liquid_assigns = controller_assigns

    expect(handler.render("{{ title }} {{ subtitle }}", local_assigns, identifier: "pages/show")).to eq("Original Local")
    expect(controller_assigns).to eq("title" => "Original")
    expect(local_assigns).to eq(subtitle: "Local")
  end

  it "separates equal template paths by namespace and source digest" do
    namespaces = ["site-1", "site-2", "site-1"]
    configuration.cache_namespace = ->(_view) { namespaces.shift }
    allow(Liquid::Template).to receive(:parse).and_call_original

    expect(handler.render("one", {}, identifier: "pages/show")).to eq("one")
    expect(handler.render("two", {}, identifier: "pages/show")).to eq("two")
    expect(handler.render("changed", {}, identifier: "pages/show")).to eq("changed")
    expect(Liquid::Template).to have_received(:parse).exactly(3).times
  end

  it "parses once for repeated complete cache keys" do
    configuration.cache_namespace = ->(_view) { "site-1" }
    allow(Liquid::Template).to receive(:parse).and_call_original

    2.times { expect(handler.render("{{ title }}", {}, identifier: "pages/show")).to eq("") }

    expect(Liquid::Template).to have_received(:parse).once
  end

  it "bypasses the cache without a namespace" do
    allow(Liquid::Template).to receive(:parse).and_call_original

    2.times { expect(handler.render("{{ title }}", {}, identifier: "pages/show")).to eq("") }

    expect(Liquid::Template).to have_received(:parse).twice
  end

  it "parses again after replacing the Liquid environment" do
    configuration.cache_namespace = ->(_view) { "site-1" }
    original_environment = Liquid::Rails.environment
    allow(Liquid::Template).to receive(:parse).and_call_original

    handler.render("Hello", {}, identifier: "pages/show")
    Liquid::Rails.environment = Liquid::Rails.build_environment(error_mode: :strict)
    handler.render("Hello", {}, identifier: "pages/show")

    expect(Liquid::Template).to have_received(:parse).twice
  ensure
    Liquid::Rails.environment = original_environment
  end

  it "uses one environment state snapshot for parsing and cache generation" do
    configuration.cache_namespace = ->(_view) { "site-1" }
    state = Liquid::Rails.environment_state
    allow(Liquid::Rails).to receive(:environment_state).and_return(state)
    expect(Liquid::Rails).not_to receive(:environment)
    expect(Liquid::Rails).not_to receive(:environment_generation)
    expect(Liquid::Template).to receive(:parse).with("Hello", environment: state.environment).and_call_original

    expect(handler.render("Hello", {}, identifier: "pages/show")).to eq("Hello")
  end

  it "raises Liquid errors when configured to raise" do
    controller.liquid_filters = [TemplateHandlerSpecErrorFilter]
    configuration.render_errors = :raise

    expect { handler.render("{{ 'value' | raise_liquid_error }}") }.to raise_error(Liquid::Error)
  end

  it "embeds Liquid errors when configured to embed" do
    controller.liquid_filters = [TemplateHandlerSpecErrorFilter]
    configuration.render_errors = :embed

    expect(handler.render("{{ 'value' | raise_liquid_error }}")).to include("Liquid error")
  end

  it "keeps application resources through nested rendering with fresh root register hashes" do
    configuration.cache_namespace = ->(_view) { "site-1" }
    resources = Object.new
    view_with_resources = TemplateHandlerSpecView.new(controller: controller, liquid_registers: {resources: resources})
    handler_with_resources = described_class.new(view_with_resources)
    original_environment = Liquid::Rails.environment
    TemplateHandlerSpecRegisterProbeTag.captures = []
    Liquid::Rails.environment = Liquid::Rails.build_environment(error_mode: :strict) do |environment|
      environment.register_tag("register_probe", TemplateHandlerSpecRegisterProbeTag)
    end
    file_system = instance_double(Liquid::Rails::FileSystem, read_template_file: "{% register_probe %}")
    allow(Liquid::Rails::FileSystem).to receive(:new).and_return(file_system)

    2.times { handler_with_resources.render("{% register_probe %}{% include 'child' %}", {}, identifier: "pages/show") }

    first_root, first_child, second_root, second_child = TemplateHandlerSpecRegisterProbeTag.captures
    expect(first_root.last).to eq(first_child.last)
    expect(second_root.last).to eq(second_child.last)
    expect(first_root.first).not_to eq(second_root.first)
  ensure
    Liquid::Rails.environment = original_environment if original_environment
  end

  it "lets framework registers override application register names" do
    application_registers = {
      view: :application_view,
      controller: :application_controller,
      helpers: :application_helpers,
      file_system: :application_file_system
    }
    view_with_registers = TemplateHandlerSpecView.new(controller: controller, liquid_registers: application_registers)
    registers = described_class.new(view_with_registers).registers

    expect(registers).to include(
      view: view_with_registers,
      controller: controller,
      helpers: ActionController::Base.helpers
    )
    expect(registers[:file_system]).to be_a(Liquid::Rails::FileSystem)
  end

  it "does not exchange assigns or tenant values across concurrent renders" do
    configuration.cache_namespace = ->(current_view) { current_view.site_id }
    handlers = 20.times.map do |number|
      tenant = "site-#{number}"
      tenant_controller = TemplateHandlerSpecController.new("tenant" => tenant)
      described_class.new(TemplateHandlerSpecView.new(controller: tenant_controller, site_id: tenant))
    end

    results = handlers.each_with_index.map do |tenant_handler, number|
      Thread.new { tenant_handler.render("{{ tenant }} {{ local }}", {local: number}, identifier: "pages/show") }
    end.map(&:value)

    expect(results).to eq(20.times.map { |number| "site-#{number} #{number}" })
  end

  it "passes Action View template metadata into generated render calls" do
    template = instance_double(
      ActionView::Template,
      source: "Hello",
      identifier: "app/views/pages/show.html.liquid",
      virtual_path: "pages/show",
      format: :html
    )

    compiled = described_class.call(template)

    expect(compiled).to include("identifier: \"app/views/pages/show.html.liquid\"")
    expect(compiled).to include("virtual_path: \"pages/show\"")
    expect(compiled).to include("format: :html")
  end
end
