# frozen_string_literal: true

puts "-RAKE START- ARGV: #{ARGV.inspect}"

# Check if running inside a Bundler environment
unless ENV["BUNDLE_GEMFILE"]
  warn "Executing Rake in the Bundle environment\n\n"
  # Rerun this Rakefile under `bundle exec`
  exec("bundle", "exec", "rake", *ARGV)
end

# Rakefile
require "rake/testtask"

task default: :test

task :test do
  subtask = Rake::TestTask.new do |t|
    t.libs << "test"
    t.test_files = FileList["test/**/*_test.rb"]
    t.verbose = true
  end
  begin
    subtask
  rescue Exception => e
    puts "Errors in task...."
    exit 1
  end
end

task :pry do
  require "pry"
  binding.pry
end

task :doc do
  sh "yard doc lib/*.rb lib/**/*.rb vendor/bundle/ruby/#{RUBY_VERSION}/gems/activemodel*/lib/**/*.rb"
end
