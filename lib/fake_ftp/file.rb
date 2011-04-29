module FakeFtp
  class File
    attr_accessor :bytes, :name
    attr_writer :type
    attr_accessor :data

    def initialize(name = nil, data = nil, type = nil)
      @name = name
      @data = data
      data_is_bytes = (data.nil? || Integer === data)
      @bytes = data_is_bytes ? data : data.length
      @data = data_is_bytes ? nil : data
      @type = type
    end

    def data=(data)
      @data = data
      @bytes = @data.nil? ? nil : data.length
    end

    def passive?
      @type == :passive
    end

    def active?
      @type == :active
    end
  end
end
