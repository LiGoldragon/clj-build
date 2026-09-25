(ns example.main-test
  (:require [clojure.test :refer [deftest is]]
            [example.main :as main]))

(deftest accepts-a-named-greeting
  (is (= {:status :ok :greeting "hello field"} (main/greet "{:name \"field\"}"))))

(deftest refuses-an-open-map
  (is (= :refused (:status (main/greet "{:name \"field\" :extra 1}")))))
