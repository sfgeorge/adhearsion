module Adhearsion
  module VoIP
    module Freeswitch
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
              break if line.empty?
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
                # FIXME: A success message is like "+OK".  Is it safe to infer
                # that error messages begin with a "-" and successes begin with "+"?
                raise EventSocketProtocolError if message[:reply_text] =~ /^\-ERR/
              end

              message[:content] = get_response(message[:content_length]) if message.has_key?(:content_length)
            when "api/response"
              message[:content] = get_response(message[:content_length]) if message.has_key?(:content_length)
            when "text/disconnect-notice"
              raise Hangup
            else
              raise EventSocketProtocolError
            end

            message
          end

          def get_response(length)
            call.io.readpartial(length.to_i).chomp.split("\n")
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