# frozen_string_literal: true

module FakeFtp
  class File
    attr_accessor :bytes, :data, :name, :last_modified_time
    attr_writer :type
    attr_reader :created

    def initialize(name = nil, data = nil, type = nil,
                   last_modified_time = Time.now)
      @created = Time.now
      @name = name
      @data = data
      # FIXME: this is far too ambiguous. args should not mean different
      # things in different contexts.
      data_is_bytes = (data.nil? || data.is_a?(Integer))
      @bytes = data_is_bytes ? data : data.to_s.length
      @data = data_is_bytes ? nil : data
      @type = type
      @last_modified_time = last_modified_time.utc
    end

    def basename
      ::File.basename(@name)
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
