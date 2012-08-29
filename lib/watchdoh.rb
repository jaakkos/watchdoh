require 'file/tail'
require 'hipchat-api'
require 'heroku-api'
require 'eventmachine'
require 'eventmachine-tail'

module Watchdoh

  class Reader < EventMachine::FileTail
    def initialize(path, startpos=-1)
      super(path, startpos)
      puts "Tailing #{path}"
      restarted
      @buffer = BufferedTokenizer.new
    end

    def receive_data(data)
      @buffer.extract(data).each do |line|
        puts "#{path}: #{line}"

        if line =~ /.*(Error R14).*/
          if worker = line.match(/(\w+.\.\d{1})/)
            if restart?
              puts "Restart worker: #{worker[0]} #{::Watchdoh::Clients.Heroku.post_ps_restart(ENV['APP_NAME'], 'ps' => worker[0]).attributes[:body]}"
              restarted
            end
          end
        end
      end
    end

    def restart?
      (@_restarted + 60).to_i < Time.now.to_i
    end

    def restarted
      @_restarted = Time.now.to_i
    end
  end


  module Clients
    def self.Heroku
      ::Heroku::API.new(api_key: ENV['HEROKU_API_KEY'])
    end

    def self.HipChat
      ::HipChat::API.new('api_token')
    end
  end

end