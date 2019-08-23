# encoding: utf-8

module Adhearsion
  class Event
    module Asterisk
      class AMI < Event
        module Decoder
          VAR_SET_ENCODING_PATTERN = /\\[abfnrtv\\'"?]/.freeze
          VAR_SET_ENCODING_MAP = {
            '\a'   => "\a",
            '\b'   => "\b",
            '\f'   => "\f",
            '\n'   => "\n",
            '\r'   => "\r",
            '\t'   => "\t",
            '\v'   => "\v",
            '\\\\' => '\\',
            "\\'"  => "'",
            '\"'   => '"',
            '\?'   => '?'
          }.freeze

          class << self
            def decode_varset_value!(value)
              value.gsub! VAR_SET_ENCODING_PATTERN, VAR_SET_ENCODING_MAP
            end
          end
        end
      end
    end
  end
end
