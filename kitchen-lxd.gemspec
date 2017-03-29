# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kitchen/driver/lxd_version'

Gem::Specification.new do |spec|
  spec.name          = 'kitchen-lxd'
  spec.version       = Kitchen::Driver::LXD_VERSION
  spec.authors       = ['Brandon Raabe']
  spec.email         = ['brandocorp@gmail.com']
  spec.description   = %q{A Test Kitchen Driver for LXD}
  spec.summary       = spec.description
  spec.homepage      = ''
  spec.license       = 'Apache 2.0'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = []
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'test-kitchen', '~> 1.0'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'pry'
end
