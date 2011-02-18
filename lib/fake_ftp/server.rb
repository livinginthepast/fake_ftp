require 'logger'

module FakeFtp
  class Server < TCPServer
    attr_accessor :directory

    COMMANDS = %w[quit type user retr stor port cdup cwd dele rmd pwd list size
                syst site mkd pass]
    LBRK = "\r\n"

    def initialize(port = 21, *args)
      @status = :started
      @logger = ::Logger.new(STDERR)

      server = super('127.0.0.1', port)

      while (@status == :started)
        begin
          socket = server.accept

          @current_thread = Thread.new(socket) do |sock|
            current_thread[:socket] = sock
            current_thread[:mode] = :binary
            log "Got connection"
            response "200 FTP server"
            while sock.nil? == false and sock.closed? == false
              request = sock.gets
              response handler(request)
            end
          end
        rescue Interrupt
          @status = :stopped
        rescue Exception => ex
          @status = :stopped
          request ||= 'No request'
          log "#{ex.class}: #{ex.message} - #{request}\n\t#{ex.backtrace[0]}"
        end
      end
    end

    def current_thread
      Thread.current
    end

    def stop
      current_thread[:status] = :stopped
    end

    def log(stuff)
      @logger.puts("[#{Time.new.ctime}] %s" % stuff)
    end

    def handler(request)
      return if request.nil? or request.to_s == ''
      begin
        command = request[0, 4].downcase.strip
        rqarray = request.split
        message = rqarray.length > 2 ? rqarray[1..rqarray.length] : rqarray[1]
        log "Request: #{command}(#{message})"
        case command
          when *COMMANDS
            __send__ command, message
          else
            bad_command command, message
        end
      rescue Errno::EACCES, Errno::EPERM
        "553 Permission denied"
      rescue Errno::ENOENT
        "553 File doesn't exist"
      rescue Exception => e
        log "Request: #{request}"
        log "Error: #{e.class} - #{e.message}\n\t#{e.backtrace[0]}"
        exit!
      end
    end

    # send a message to the client
    def response(message)
      sock = current_thread[:socket]
      sock.print message << LBRK unless msg.nil? or sock.nil? or sock.closed?
    end

    # command not understood
    def bad_command(name, *params)
      arg = (params.is_a? Array) ? params.join(' ') : params
      if @config[:debug]
        "500 I don't understand " << name.to_s << "(" << arg << ")"
      else
        "500 Sorry, I don't understand #{name.to_s}"
      end
    end

    def next_state(current)
      @status = case current
                  when :connect
                    :waiting
                  when :waiting
                    :complete
                  when :complete
                    :finished
                end
    end

    def user(msg)
      "230 OK, logging in"
    end

    def pass(msg)
      "230 Password accepted"
    end

    # quit the ftp session
    def quit(msg = false)
      current_thread[:socket].close
      current_thread[:socket] = nil
      log "User #{current_thread[:user]} disconnected."
      "221 Laterz"
    end
  end
end