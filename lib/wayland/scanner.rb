require 'rexml/document'

module Wayland
  class Scanner
    def initialize(doc)
      @doc = doc
    end
    attr_reader :doc

    def mkargs(elements)
      elements.map do |arg|
        ahash = {}
        [ "name", "type", "interface", "enum" ].each do |attr|
          val = arg.attribute attr
          ahash[attr.to_sym] = val.to_s.to_sym if val
        end
        val = arg.attribute "allow-null"
        if val
          sval = val.to_s
          ahash[:allow_null] = (sval == "true")
        end
        ahash
      end
    end
    private :mkargs

    def scan
      interfaces = {}

      doc.get_elements("/protocol/interface").each do |e|
        intf = { version: e.attribute("version").to_s.to_i }
        requests = {}
        e.get_elements("request").each_with_index do |req, i|
          requests[req.attribute("name").to_s.to_sym] =           
            { opcode: i, args: mkargs(req.get_elements("arg")) }
        end
        intf[:requests] = requests

        events = []
        e.get_elements("event").each_with_index do |ev, i|
          name = ev.attribute("name").to_s.to_sym
          args = mkargs ev.get_elements("arg")
          ev_spec = { opcode: i, name: name, args: args }
          since = ev.attribute("since")
          ev_spec[:since] = since.to_s.to_i if since
          events << ev_spec
        end
        intf[:events] = events

        enums = []
        e.get_elements("enum").each do |en|
          name = en.attribute("name").to_s.to_sym
          entries = en.get_elements("entry")
          en_spec = { name: name }
          en_spec[:entries] = entries.map do |ent|
            { name: ent.attribute("name").to_s.to_sym,
              value: Integer(ent.attribute("value").to_s) }
          end
          enums << en_spec
        end
        intf[:enums] = enums

        name = e.attribute("name").to_s.to_sym
        interfaces[name] = intf
      end
      interfaces
    end
  end
end
