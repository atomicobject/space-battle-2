(ns rts.server
  (:require [rts.server.networking :as net]
            [rts.ai :as ai]
            [com.stuartsierra.component :as component]
            [clojure.pprint :refer [pprint]]
            [clojure.core.async :as a :refer [go go-loop >! <!]]))

(defn game-state-chan
  "Provides a channel of game states. Game states are derived using the
   supplied recv chan and init-fn and update-fn. By default, a sliding
   buffer is used so that intermediate states are dropped. You can supply
   your own channel for game states to be placed on, if you wish."

  ([recv init-state update-fn]
   (game-state-chan recv init-state update-fn (a/sliding-buffer 1)))

  ([recv init-state update-fn out-chan]
   (let [last-val (volatile! init-state)]
     (a/map
      #(vswap! last-val update-fn %)
      [recv]
      out-chan))))

(defn run-game-client [recv send]
  (let [full-states (game-state-chan recv ai/initial-game-state ai/update-game)]
    (go-loop [ai-state ai/initial-ai-state]
      (if-let [next-state (<! full-states)]
        (let [[next-ai-state commands] (ai/play ai-state next-state)]
          (>! send commands)
          (recur next-ai-state))))))

(defn run-client-acceptor [new-clients runfn]
  (go-loop []
    (when-let [[recv send] (<! new-clients)]
      (runfn recv send)
      (recur))))

(defrecord Server [port play-fn
                   new-clients shutdown]
  component/Lifecycle
  (start [this]
    (let [[new-clients shutdown] (net/start-listening port)]
      (run-client-acceptor new-clients run-game-client)
      (assoc this
             :new-clients new-clients
             :shutdown shutdown)))

  (stop [this]
    (a/close! shutdown)
    (assoc this
           :new-clients nil
           :shutdown nil)))

(defn new-server [port]
  (map->Server {:port port}))
