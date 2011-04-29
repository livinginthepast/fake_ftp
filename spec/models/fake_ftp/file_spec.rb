require "spec_helper.rb"

describe FakeFtp::File do
  context 'attributes' do
    before :each do
      @file = FakeFtp::File.new
    end

    it "has a name attribute" do
      @file.name = "some name"
      @file.name.should == "some name"
    end

    it "has a bytes attribute" do
      @file.bytes = 87
      @file.bytes.should == 87
    end

    it "has a data attribute" do
      @file.data = 'some data'
      @file.data.should == 'some data'
      @file.bytes.should == 'some data'.length
    end
  end

  context 'setup' do
    it "can be initialized without attributes" do
      file = FakeFtp::File.new
      file.name.should be_nil
      file.bytes.should be_nil
      file.instance_variable_get(:@type).should be_nil
    end

    it "can be initialized with name" do
      file = FakeFtp::File.new('filename')
      file.name.should == 'filename'
      file.bytes.should be_nil
      file.instance_variable_get(:@type).should be_nil
    end

    it "can be initialized with name and bytes" do
      file = FakeFtp::File.new('filename', 104)
      file.name.should == 'filename'
      file.bytes.should == 104
      file.instance_variable_get(:@type).should be_nil
    end
    
    it "can be initialized with name and bytes and type" do
      file = FakeFtp::File.new('filename', 104, :passive)
      file.name.should == 'filename'
      file.bytes.should == 104
      file.instance_variable_get(:@type).should == :passive
    end
  end

  describe '#passive?' do
    before :each do
      @file = FakeFtp::File.new
    end

    it "should be true if type is :passive" do
      @file.type = :passive
      @file.passive?.should be_true
    end

    it "should be false if type is :active" do
      @file.type = :active
      @file.passive?.should be_false
    end
  end

  describe '#active?' do
    before :each do
      @file = FakeFtp::File.new
    end

    it "should be true if type is :active" do
      @file.type = :active
      @file.active?.should be_true
    end

    it "should be false if type is :passive" do
      @file.type = :passive
      @file.active?.should be_false
    end
  end
end
