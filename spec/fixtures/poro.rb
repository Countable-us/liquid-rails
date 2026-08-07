class Model
  include Liquid::Rails::Droppable

  def initialize(hash = {})
    @attributes = hash
  end

  def id
    @attributes[:id] || @attributes["id"] || object_id
  end

  def respond_to?(method, include_private = false)
    return true if @attributes.key?(method)
    super
  end

  def respond_to_missing?(method, include_private = false)
    @attributes.key?(method) || super
  end

  def method_missing(meth, *args)
    if meth.to_s =~ /^(.*)=$/
      @attributes[$1.to_sym] = args[0]
    elsif @attributes.key?(meth)
      @attributes[meth]
    else
      super
    end
  end
end

class Profile < Model
end

class ConventionOnly
end

class ConventionOwner
  attr_accessor :resource
end

class PaginatedComments
  include Enumerable

  def initialize(items)
    @items = items
  end

  def each(&block)
    @items.each(&block)
  end

  def approved
    self
  end

  def page(_number)
    self
  end

  def per(_number)
    self
  end
end

class ProfileDrop < Liquid::Rails::Drop
  attributes :name, :description
end

class ConventionOnlyDrop < Liquid::Rails::Drop
end

class ConventionOwnerDrop < Liquid::Rails::Drop
  belongs_to :resource
end

Post = Class.new(Model)
Comment = Class.new(Model)

PostDrop = Class.new(Liquid::Rails::Drop) do
  attributes :title, :body, :id
  has_many :comments
  has_many :recomments, with: "ReCommentDrop", class_name: "CommentsDrop"
end

CommentDrop = Class.new(Liquid::Rails::Drop) do
  attributes :id, :body
  belongs_to :post
  belongs_to :repost, class_name: "RePostDrop"
end

ReProfileDrop = Class.new(Liquid::Rails::Drop)
PostsDrop = Class.new(Liquid::Rails::CollectionDrop)
RePostDrop = Class.new(Liquid::Rails::Drop)
ReCommentDrop = Class.new(Liquid::Rails::Drop)
CommentsDrop = Class.new(Liquid::Rails::CollectionDrop) do
  scope :approved
end
