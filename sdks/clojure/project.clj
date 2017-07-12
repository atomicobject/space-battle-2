(defproject ao-rts "0.1.0-SNAPSHOT"
  :main rts.core
  :repl-options {:init-ns rts.repl}
  :dependencies [[org.clojure/clojure "1.9.0-alpha17"]
                 [org.clojure/core.async "0.3.442"]
                 [com.stuartsierra/component "0.3.2"]
                 [org.clojure/tools.namespace "0.2.11"]
                 [cheshire "5.7.1"]
                 [camel-snake-kebab "0.4.0"]]
  :profiles {:dev {:dependencies [[circleci/circleci.test "0.2.0"]
                                  [org.clojure/test.check "0.9.0"]]}})
