(ns rts.ai)

(def initial-game-state
  "This var is used when a new game is started. Its value should represent a new,
   fresh game, before any updates have been applied. Its value will be passed into
   your update-game fn the first time it is invoked."

  ;; Replace this code
  {:ok-computer true
   :times 0})

(def initial-ai-state
  "This var is used when a new game is started. Its value should represent a blank slate
   for any context you wish for your AI to have. What you do with it is up to you.
   At the very least, you may want to track which turn you're on so you know if your
   AI is taking too long to play and skipping turns."

  {:ai-ctr 0})

(defn update-game
  "This function receives the previous state of the game as well as
  the update message provided by the server. It should return the new state."
  [game-state server-update-message]

  ;; Replace this code
  (assoc game-state :turn (:turn server-update-message)))

(defn play
  "This fn receives an ai-state and a game-state, and then decides what moves to play.
   Should return a pair of [new-ai-state server-command], where the server-command is
   the message that will be sent, verbatim, to the server."
  [ai-state game-state]

  (println "ai-state:   " ai-state)
  (println "game-state: " game-state)

  ;; Replace this code
  [(update ai-state :ai-ctr inc)
   (if (< (:turn game-state) 5)
     {:commands [{:command "CREATE"
                  :type "worker"}]}
     {:commands []})])
