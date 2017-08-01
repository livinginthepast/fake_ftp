# frozen_string_literal: true

begin
  require 'bundler'
  require 'rspec/core/rake_task'
  require 'rubocop/rake_task'
rescue LoadError => e
  warn e
end

Bundler::GemHelper.install_tasks if defined?(Bundler)
RSpec::Core::RakeTask.new if defined?(RSpec)
RuboCop::RakeTask.new if defined?(RuboCop)

task default: %i[rubocop spec]
