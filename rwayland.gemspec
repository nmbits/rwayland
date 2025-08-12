Gem::Specification.new do |s|
  s.authors               = ['nmbits']
  s.files                 = ['LICENSE', 'README.md'] +
                            Dir['lib/**/*.{rb,yaml,erb}'] + Dir['bin/*.rb'] + Dir['example/**/*.rb']
  s.name                  = 'rwayland'
  s.summary               = 'Ruby bindings for Wayland protocol.'
  s.version               = '0.1.1'

  s.description           = 'Ruby bindings for Wayland protocol.'
  s.email                 = ['nmbits@gmail.com']
  s.homepage              = 'https://github.com/nmbits/rwayland'
  s.license               = 'MIT'
  s.required_ruby_version = '>= 3.3'
end
