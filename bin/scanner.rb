if __FILE__ == $0
  require 'wayland/scanner'
  require 'yaml'
  doc = REXML::Document.new ARGF
  scanner = Wayland::Scanner.new doc
  interfaces = scanner.scan
  print YAML.dump(interfaces)
end
