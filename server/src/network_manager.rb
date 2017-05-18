require 'socket'
class Connection

  def self.open(network_manager, host, port)
    new(network_manager, host, port)
  end

  def initialize(network_manager, host, port)
    @socket = TCPSocket.open host, port
    GameLogger.log("Connected to #{host}:#{port}")
    @alive = true
    @host = host
    @port = port
    @messages = []
    @outgoing = []
    @mutex = Mutex.new
    @network_manager = network_manager
  end

  def alive?
    @alive
  end

  def has_message_pending?
    @pending
  end

  def pop_messages!
    msgs = nil
    @mutex.synchronize do
      msgs = @messages
      @messages = []
      @pending = false
    end
    msgs
  end

  def start
    @thread = Thread.start do
      begin
        loop do
          msg = @socket.gets
          @mutex.synchronize do
            @messages << msg
            @pending = true
          end
          @network_manager.new_message_recieved
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
      Oj.load(@json)
      # JSON.parse(@json)
    rescue
    end
  end

  def to_s
    "msg for #{@connection_id}:\n#{@json}"
  end
end

class NetworkManager
  attr_reader :messages_queue

  def clients
    @connections.keys
  end

  def initialize
    @connection_count = 0
    @connections = {}
    @messages_queue = Queue.new
  end

  def message_received_for_all_clients?
    # TODO need a mutex here?
    @connections.values.all?(&:has_message_pending?)
  end

  def new_message_recieved
    if message_received_for_all_clients?
      @messages_queue << pop_messages!
    end
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
      conn.pop_messages!.map do |msg|
        Message.from_json(id, "#{msg}".strip)
      end
    end
  end

  private
  def _connect(host, port)
    Connection.open(self, host, port)
  end
end

