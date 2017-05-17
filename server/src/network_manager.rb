require 'socket'
class Connection
  attr_reader :messages

  def self.open(host, port)
    new(host, port)
  end

  def initialize(host, port)
    @socket = TCPSocket.open host, port
    GameLogger.log("Connected to #{host}:#{port}")
    @alive = true
    @host = host
    @port = port
    @messages = []
    @outgoing = []
    @mutex = Mutex.new
  end

  def alive?
    @alive
  end

  def clear!
    @mutex.synchronize do
      @messages = []
    end
  end

  def start
    @thread = Thread.start do
      begin
        loop do
          msg = @socket.gets
          @mutex.synchronize do
            @messages << msg
          end
        end
      rescue
        puts "Client at #{@host}:#{@port} died"
        @alive = false
      end
    end
  end

  def write(json)
    return unless @alive
    # puts "queueing writing #{json}"
    @mutex.synchronize do
      @outgoing << json
    end
  end

  def flush!
    return unless @alive
    # puts "flushing conn"
    @mutex.synchronize do
      @outgoing.each do |msg|
        # puts "writing #{msg}"
        @socket.puts msg
      end
      @outgoing.clear
    end
  end

  def stop
    @alive = false
    Thread.kill(@thread) if @thread
    @socket.close if @socket
  end
end

class Message
  attr_reader :connection_id, :json

  def self.from_json(connection_id, json)
    Message.new(connection_id, json)
  end

  def initialize(connection_id, json)
    @connection_id = connection_id
    @json = json
  end

  def data
    begin
      JSON.parse(@json)
    rescue
    end
  end

  def to_s
    "msg for #{@connection_id}:\n#{@json}"
  end
end

class NetworkManager
  def clients
    @connections.keys
  end

  def initialize
    @connection_count = 0
    @connections = {}
  end

  def connect(host, port)
    puts "connecting..."
    conn = _connect(host, port)
    @connections[@connection_count] = conn
    @connection_count += 1
    conn.start
  end

  def write(id, msg)
    conn = @connections[id]
    raise "unknown player: #{id}" unless conn
    conn.write(msg)
  end

  def flush!
    @connections.values.each do |conn|
      conn.flush!
    end
  end
  
  def pop_messages!

    @connections.flat_map do |id, conn|
      msgs = conn.messages.map do |msg|
        Message.from_json(id, "#{msg}".strip)
      end
      conn.clear!
      msgs
    end
  end

  private
  def _connect(host, port)
    Connection.open(host, port)
  end
end

