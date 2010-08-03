require 'adhearsion/voip/dsl/dialplan/thread_mixin'
require 'adhearsion/voip/dsl/dialplan/parser'
require 'adhearsion/voip/dsl/dialplan/dispatcher'
require 'eventmachine'
#require 'adhearsion/voip/freeswitch/basic_connection_manager'
#require 'adhearsion/voip/freeswitch/freeswitch_dialplan_command_factory'

module Adhearsion
  module VoIP
    module FreeSwitch
      class EventSocket
        class OESServer
          class << self
            def initialize(port, host)
              @host, @port = host, port
            end

            def graceful_shutdown
              ahn_log.oes.info "Shutting down Outbound EventSocket listener"
              EventMachine::stop_event_loop
            end

            def start
             EventMachine::run {
               EventMachine::start_server @host, @port, self
               ahn_log.oes.info "Opening FreeSWITCH Outbound EventSocket listener on #{@host}:#{@port}"
             }
            end
          end

          def receive_data(data)
            @buffer << data
            while message = @buffer.slice!( /^[^\n]*[\n]/m )
              ahn_log.oes.debug "<<< #{message}"
            end
          end
        end
      end
    end
  end
end
