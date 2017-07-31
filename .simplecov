if ENV['COVERAGE'] == '1'
  SimpleCov.start do
    add_filter '/spec/'
    minimum_coverage 90
  end
end
