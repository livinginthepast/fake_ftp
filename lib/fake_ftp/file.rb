module FakeFtp
  class File
    attr_accessor :bytes, :name

    def initialize(name = nil, bytes = nil)
      self.name = name
      self.bytes = bytes
    end
  end
end
