module FakeFtp
  class File
    attr_accessor :bytes, :name
    attr_writer :type

    def initialize(name = nil, bytes = nil, type = nil)
      self.name = name
      self.bytes = bytes
      self.type = type
    end

    def passive?
      @type == :passive
    end

    def active?
      @type == :active
    end
  end
end
