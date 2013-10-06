require 'spec_helper'

describe FakeFtp::Command, '::push and ::find' do
  it 'allows a pushed class to be found by name' do
    class Thing; end

    expect {
      FakeFtp::Command.push Thing
    }.to change { FakeFtp::Command.find 'thing' }.from(nil).to(Thing)
  end
end

describe FakeFtp::Command, '::process' do
  let(:server) { double('Server') }

  context 'request matches a command' do
    let(:command) { double('BlarClass') }
    let(:command_instance) { double('Blar') }

    it 'runs the command with server and the message content' do
      FakeFtp::Command.should_receive('find').with('dosomething').and_return(command)
      command.should_receive('new').with(server).and_return(command_instance)
      command_instance.should_receive('run').with('blar', 'blan', 'blah').and_return('200 Awesome!!!!!')


      expect(
        FakeFtp::Command.process(server, 'DOSOMETHING blar blan blah')
      ).to eql('200 Awesome!!!!!')
    end
  end

  context 'request does not match a class' do
    it 'returns a 500 response' do
      expect(
        FakeFtp::Command.process(server, 'BLAH blah blah blah')
      ).to eql('500 Unknown command')
    end
  end
end
