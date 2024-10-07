# frozen_string_literal: true

# Check if running inside a Bundler environment
unless ENV['BUNDLE_GEMFILE']
  warn "Executing Rake in the Bundle environment\n\n"
  # Rerun this Rakefile under `bundle exec`
  exec('bundle', 'exec', 'rake', *ARGV)
end

# Rakefile
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/**/*_test.rb']
  t.verbose = true
end

task default: :test

task :pry do
  require 'pry'
  binding.pry
end

task :doc do
  sh "yard doc lib/*.rb lib/**/*.rb"
end
