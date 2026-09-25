(ns example.main
  (:require [clojure.edn :as edn]
            [malli.core :as m]))

(def Greeting
  [:map {:closed true} [:name [:string {:min 1}]]])

(defn greet [input]
  (let [value (edn/read-string input)]
    (if (m/validate Greeting value)
      {:status :ok :greeting (str "hello " (:name value))}
      {:status :refused :reason :invalid-input})))

(defn -main [& args]
  (let [result (greet (or (first args) "nil"))]
    (prn result)
    (System/exit (if (= :ok (:status result)) 0 1))))
