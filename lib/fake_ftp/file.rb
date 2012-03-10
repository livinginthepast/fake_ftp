module FakeFtp
  class File
    attr_accessor :bytes, :name
    attr_writer :type
    attr_accessor :data
    attr_reader :created

    def initialize(name = nil, data = nil, type = nil)
      @created = Time.now
      @name = name
      @data = data
      # FIXME this is far too ambiguous. args should not mean different
      # things in different contexts.
      data_is_bytes = (data.nil? || Integer === data)
      @bytes = data_is_bytes ? data : data.to_s.length
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
