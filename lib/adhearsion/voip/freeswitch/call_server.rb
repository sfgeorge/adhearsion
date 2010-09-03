module Adhearsion
  module VoIP
    module Freeswitch
      class OESServer < Adhearsion::VoIP::CallServer::RubyServer
        def serve(io)
          io.print "connect\n\n"
          super
        end
      end
    end
  end
end