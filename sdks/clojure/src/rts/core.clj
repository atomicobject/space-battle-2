(ns rts.core
  (:require [rts.server :as server]
            [com.stuartsierra.component :as component]))

(defn new-system [port]
  (component/system-map
   :server (server/new-server port)))

(defn -main []
  (component/start (new-system 9090)))
