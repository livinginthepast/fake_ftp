require "spec_helper.rb"

describe FakeFtp::File do
  context 'attributes' do
    before :each do
      @file = FakeFtp::File.new
    end

    it "has a name attribute" do
      @file.name = "some name"
      expect(@file.name).to eql("some name")
    end

    it "has a last_modified_time attribute" do
      now = Time.now
      @file.last_modified_time = now
      expect(@file.last_modified_time).to eql(now)
    end

    it "has a bytes attribute" do
      @file.bytes = 87
      expect(@file.bytes).to eql(87)
    end

    it "has a data attribute" do
      @file.data = 'some data'
      expect(@file.data).to eql('some data')
      expect(@file.bytes).to eql('some data'.length)
    end
  end

  context 'setup' do
    it "can be initialized without attributes" do
      file = FakeFtp::File.new
      expect(file.name).to be_nil
      expect(file.bytes).to be_nil
      expect(file.instance_variable_get(:@type)).to be_nil
    end

    it "can be initialized with name" do
      file = FakeFtp::File.new('filename')
      expect(file.name).to eql('filename')
      expect(file.bytes).to be_nil
      expect(file.instance_variable_get(:@type)).to be_nil
    end

    it "can be initialized with name and bytes" do
      file = FakeFtp::File.new('filename', 104)
      expect(file.name).to eql('filename')
      expect(file.bytes).to eql(104)
      expect(file.instance_variable_get(:@type)).to be_nil
    end

    it "can be initialized with name and bytes and type" do
      file = FakeFtp::File.new('filename', 104, :passive)
      expect(file.name).to eql('filename')
      expect(file.bytes).to eql(104)
      expect(file.instance_variable_get(:@type)).to eql(:passive)
    end

    it "can be initialized with name and bytes and type and last_modified_time" do
      time = Time.now
      file = FakeFtp::File.new('filename', 104, :passive, time)
      expect(file.name).to eql('filename')
      expect(file.bytes).to eql(104)
      expect(file.instance_variable_get(:@type)).to eql(:passive)
      expect(file.last_modified_time).to eql(time)
    end
  end

  describe '#passive?' do
    before :each do
      @file = FakeFtp::File.new
    end

    it "should be true if type is :passive" do
      @file.type = :passive
      expect(@file.passive?).to be_true
    end

    it "should be false if type is :active" do
      @file.type = :active
      expect(@file.passive?).to be_false
    end
  end

  describe '#active?' do
    before :each do
      @file = FakeFtp::File.new
    end

    it "should be true if type is :active" do
      @file.type = :active
      expect(@file.active?).to be_true
    end

    it "should be false if type is :passive" do
      @file.type = :passive
      expect(@file.active?).to be_false
    end
  end
end
