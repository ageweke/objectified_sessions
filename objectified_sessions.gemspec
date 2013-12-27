# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'objectified_sessions/version'

Gem::Specification.new do |s|
  s.name          = "objectified_sessions"
  s.version       = ObjectifiedSessions::VERSION
  s.authors       = ["Andrew Geweke"]
  s.email         = ["andrew@geweke.org"]
  s.description   = %q{Encapsulate and carefully manage access to your Rails session.}
  s.summary       = %q{Encapsulate and carefully manage access to your Rails session.}
  s.homepage      = "https://github.com/ageweke/objectified_sessions"
  s.license       = "MIT"

  s.files         = `git ls-files`.split($/)
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|s|features)/})
  s.require_paths = ["lib"]

  s.add_development_dependency "bundler", "~> 1.3"
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec", "~> 2.14"

  if (RUBY_VERSION =~ /^1\.9\./ || RUBY_VERSION =~ /^2\.0\./) && ((! defined?(RUBY_ENGINE)) || (RUBY_ENGINE != 'jruby'))
    s.add_development_dependency "pry"
    s.add_development_dependency "pry-debugger"
    s.add_development_dependency "pry-stack_explorer"
  end

  actionpack_version = ENV['FLEX_COLUMNS_ACTIONPACK_TEST_VERSION']
  actionpack_version = actionpack_version.strip if actionpack_version

  version_spec = case actionpack_version
  when nil then [ ">= 3.0", "<= 4.99.99" ]
  when 'master' then nil
  else [ "=#{actionpack_version}" ]
  end

  if version_spec
    s.add_dependency("rails", *version_spec)
  end
end
