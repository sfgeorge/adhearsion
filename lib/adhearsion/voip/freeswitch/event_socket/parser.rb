module Adhearsion
  module VoIP
    module FreeSwitch
      module EventSocket
        module Parser

          def read_response
            last_line = "init"
            buffer = []
            until last_line.empty? do
              buffer << last_line = call.io.readline.chomp
            end

            if buffer[0] =~ /^disconnected/i
              raise Hangup, "Disconnected from OES"
            end

            message = EventSocketResponse.new
            buffer.each {|line|
              key, val = line.split(" ", 2)
              key.gsub!(/:$/, '')
              key.gsub!(/-/, '_')
              key.downcase!
              message[key.to_sym] = val
            }

            case message[:content_type]
            when "command/reply"
              # Standard response
              if message.has_key?(:reply_text)
                raise EventSocketProtocolError if message[:reply_text] =~ /^\-ERR/
              end
            when "text/disconnect-notice"
              raise Hangup
            else
              raise EventSocketProtocolError
            end

            message
          end
        end

        class EventSocketResponse

          def initialize
            @headers = HashWithIndifferentAccess.new
          end

          def headers
            @headers.clone
          end

          def [](arg)
            @headers[arg]
          end

          def []=(key,value)
            @headers[key] = value
          end

          def has_key?(key)
            @headers.has_key?(key)
          end
        end

        class EventSocketProtocolError < StandardError
        end

      end
    end
  end
end