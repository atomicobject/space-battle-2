(ns rts.server.messages
  (:require [clojure.spec.alpha :as s]))

(def directions #{"N" "S" "E" "W"})
(def command-types #{"MOVE" "GATHER" "ATTACK" "CREATE"})
(def unit-types #{"base" "worker" "scout" "tank"})

(def unit-statuses #{"unknown" "dead" "moving" "idle"})

(s/def :srv.command/command command-types)

(s/def :srv.command/type #{})
(s/def :srv/unit int?)
(s/def :srv/dir directions)
(s/def :srv.command/dx int?)
(s/def :srv.command/dy int?)
(s/def :srv/id int?)

(defmulti command-type :command)
(defmethod command-type "create" [_]
  (s/keys :req-un [:srv.command/command
                   :srv.command/type]))
(defmethod command-type "attack" [_]
  (s/keys :req-un [:srv.command/command
                   :srv/unit
                   :srv.command/dx
                   :srv.command/dy]))
(defmethod command-type :default [_]
  (s/keys :req-un [:srv.command/command
                   :srv/unit
                   :srv/dir]))
(s/def ::command
  (s/multi-spec command-type :srv.command/command))

(s/def :srv.update/player int?)
(s/def :srv.update/turn int?)
(s/def :srv.update/time int?)

(s/def :srv.tile-update/x int?)
(s/def :srv.tile-update/y int?)
(s/def :srv.tile-update/visible boolean?)
(s/def :srv.tile-update/blocked boolean?)
(s/def :srv.tile-update/units (s/* :srv/unit-update))

(def resource-types #{"small"})
(s/def :srv.resources/type resource-types)
(s/def :srv.resources/value int?)
(s/def :srv.resources/total int?)
(s/def :srv/resources
  (s/nilable (s/keys :req-un [:srv/id
                              :srv.resources/type
                              :srv.resources/value
                              :srv.resources/total])))

(s/def :srv/tile-update
  (s/keys :req-un [:srv.tile-update/x
                   :srv.tile-update/y
                   :srv.tile-update/visible
                   :srv.tile-update/blocked
                   :srv.tile-update/units
                   :srv/resources]))

(s/def :srv/tile-updates (s/* :srv/tile-update))

(s/def :srv.unit-update/player-id int?)
(s/def :srv.unit-update/x int?)
(s/def :srv.unit-update/y int?)
(s/def :srv.unit-update/resource int?)
(s/def :srv.unit-update/health int?)
(s/def :srv.unit-update/can-attack boolean?)
(s/def :srv.unit-update/type unit-types)
(s/def :srv.unit-update/status unit-statuses)

(s/def :srv/unit-update
  (s/keys :req-un [:srv/id
                   :srv.unit-update/player-id
                   :srv.unit-update/x
                   :srv.unit-update/y
                   :srv.unit-update/status
                   :srv.unit-update/type
                   :srv.unit-update/resource
                   :srv.unit-update/health]
          :opt-un [:srv.unit-update/can-attack]))

(s/def :srv/unit-updates (s/* :srv/unit-update))

(s/def ::update
  (s/keys :req-un [:srv/unit-updates
                   :srv/tile-updates
                   :srv.update/player
                   :srv.update/turn
                   :srv.update/time]))
