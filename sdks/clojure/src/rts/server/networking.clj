(ns rts.server.networking
  "This whole namespace is for networking. Core async is used (will I ever learn?).
  It's fundamentally based around sending and receiving arbitrary json 'packets'.

  All of this networking code is awful. please don't judge me."
  (:require [clojure.core.async :as a :refer [chan put! close! go <!]]
            [clojure.java.io :as io]
            [cheshire.core :as json]
            [camel-snake-kebab.core :as case])
  (:import [java.io BufferedReader InputStreamReader PrintWriter]
           [java.net Socket ServerSocket InetSocketAddress]))

(defn- run-session [client [recv send]]
  (let [writer (io/writer client)
        reader (io/reader client)
        instream (line-seq reader)
        shutdown (fn []
                   (close! recv)
                   (close! send)
                   (.close reader)
                   (.close writer))]
    (future
      (try
        (loop []
          (when-let [msg (a/<!! send)]
            (.write writer (json/generate-string msg {:key-fn case/->snake_case_string}))
            (.write writer "\n")
            (.flush writer)
            (recur)))
        (finally
          (shutdown))))
    (future
      (try
        (doseq [msg instream]
          (put! recv (json/parse-string msg case/->kebab-case-keyword)))
        (finally
          (shutdown))))))

(defn start-listening [server-port]
  "Open server socket on port. Return a channel that will yield a pair of
  [[receive send] close]"
  (let [sessions (chan)
        shutdown (chan)
        server (ServerSocket. server-port)]
    (go
      (<! shutdown)
      (.close server))
    (future
      (loop []
        (when-let [client (.accept server)]
          (let [recv (chan)
                send (chan)
                client-chans [recv send]]
            (put! sessions client-chans)
            (run-session client client-chans)
            (recur)))))
    [sessions shutdown]))
