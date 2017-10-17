class GameLogger
  class NOOP
    def method_missing(*args)
    end
  end

  def initialize(file_name='game-log.txt')
    @log_file = File.open(file_name, 'w+')
  end

  def log(msg)
    @log_file.puts msg
    @log_file.flush
  end

  def log_game_state(em, turn)
    log({turn: turn, time: Time.now.to_ms, type: :game_state, state: em.id_to_comp}.to_json)
  end

  def log_connection(pid, host, port)
    log({time: Time.now.to_ms, type: :connection, id: pid, host: host, port: port}.to_json)
  end

  def log_sent(pid, data)
    log({time: Time.now.to_ms, type: :to_player, id: pid, msg: data}.to_json)
  end

  def log_received(pid, data)
    log({time: Time.now.to_ms, type: :from_player, id: pid, msg: data}.to_json)
  end
end


