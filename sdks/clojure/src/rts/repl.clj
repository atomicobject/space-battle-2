(ns rts.repl
  (:require [clojure.tools.namespace.repl :refer [refresh]]
            [com.stuartsierra.component :as component]
            [clojure.pprint :refer [pprint]]
            [clojure.repl :refer :all]
            [rts.core :refer [new-system]]))

(def system nil)
(def port 42420)

(defn init []
  (alter-var-root #'system (constantly (new-system port))))

(defn start []
  (alter-var-root #'system component/start))

(defn stop []
  (alter-var-root #'system component/stop))

(defn go []
  (init)
  (start))

(defn restart []
  (stop)
  (refresh :after 'rts.repl/go))

                                        ; (go)
                                        ; (restart)
