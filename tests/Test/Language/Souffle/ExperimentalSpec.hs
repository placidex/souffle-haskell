
{-# LANGUAGE DeriveGeneric, TypeApplications, QuasiQuotes, TypeOperators, DataKinds, TypeFamilies #-}

module Test.Language.Souffle.ExperimentalSpec
  ( module Test.Language.Souffle.ExperimentalSpec
  ) where


import Test.Hspec
import GHC.Generics
import Control.Applicative
import Data.Int
import Language.Souffle.Experimental
import Language.Souffle.Experimental.Render
import Language.Souffle.Experimental.Types (Atom(Var))
import NeatInterpolation

data IntFact = IntFact Int32
  deriving Generic

data Triple = Triple String Int32 String
  deriving Generic

data Edge = Edge String String
  deriving Generic

data Reachable = Reachable String String
  deriving Generic


spec :: Spec
spec = fdescribe "Souffle DSL" $ parallel $ do
  describe "code generation" $ parallel $ do
    let prog ==> txt = render (runDSL prog) `shouldBe` (txt <> "\n")

    it "can render an empty program" $ do
      render (runDSL $ pure ()) `shouldBe` ""

    it "can render a program with an input type definition" $ do
      let prog = do
            Predicate _ <- typeDef @Edge In
            pure ()
      prog ==> [text|
        .decl edge(t1: symbol, t2: symbol)
        .input edge
        |]

    it "can render a program with an output type definition" $ do
      let prog = do
            Predicate _ <- typeDef @Edge Out
            pure ()
      prog ==> [text|
        .decl edge(t1: symbol, t2: symbol)
        .output edge
        |]

    it "can render a program with type declared both as in- and output" $ do
      let prog = do
            Predicate _ <- typeDef @Edge InOut
            pure ()
      prog ==> [text|
        .decl edge(t1: symbol, t2: symbol)
        .input edge
        .output edge
        |]

    it "renders type declaration based on type info" $ do
      let prog = do
            Predicate _ <- typeDef @IntFact In
            Predicate _ <- typeDef @Triple Out
            pure ()
      prog ==> [text|
        .decl intfact(t1: number)
        .input intfact
        .decl triple(t1: symbol, t2: number, t3: symbol)
        .output triple
        |]

    -- TODO: it "uses record accessors as attribute names in type declaration if provided" pending

    it "can render facts" $ do
      let prog = do
            Predicate edge <- typeDef @Edge In
            Predicate triple <- typeDef @Triple In
            edge("a", "b")
            triple("cde", 1000, "fgh")
      prog ==> [text|
        .decl edge(t1: symbol, t2: symbol)
        .input edge
        .decl triple(t1: symbol, t2: number, t3: symbol)
        .input triple
        edge("a", "b").
        triple("cde", 1000, "fgh").
        |]

    it "can render a relation with a single rule" $ do
      let prog = do
            Predicate edge <- typeDef @Edge In
            Predicate reachable <- typeDef @Reachable Out
            let a = Var "a"
                b = Var "b"
            reachable(a, b) |- edge(a, b)
      prog ==> [text|
        .decl edge(t1: symbol, t2: symbol)
        .input edge
        .decl reachable(t1: symbol, t2: symbol)
        .output reachable
        reachable(a, b) :-
          edge(a, b).
        |]

    it "can render a relation with multiple rules" $ do
      let prog = do
            Predicate edge <- typeDef @Edge In
            Predicate reachable <- typeDef @Reachable Out
            let a = Var "a"
                b = Var "b"
            reachable(a, b) |- do
              edge(a, a)
              edge(b, b)
              edge(a, b)
      prog ==> [text|
        .decl edge(t1: symbol, t2: symbol)
        .input edge
        .decl reachable(t1: symbol, t2: symbol)
        .output reachable
        reachable(a, b) :-
          edge(a, a),
          edge(b, b),
          edge(a, b).
        |]

    it "can render a relation with a logical or in the rule block" $ do
      let prog = do
            Predicate edge <- typeDef @Edge In
            Predicate reachable <- typeDef @Reachable Out
            let a = Var "a"
                b = Var "b"
            reachable(a, b) |- do
              let rules1 = do
                    edge(a, a)
                    edge(b, b)
                  rules2 = do
                    edge(a, b)
                    edge(b, a)
              rules1 <|> rules2
      prog ==> [text|
        .decl edge(t1: symbol, t2: symbol)
        .input edge
        .decl reachable(t1: symbol, t2: symbol)
        .output reachable
        reachable(a, b) :-
          edge(a, a),
          edge(b, b);
          edge(a, b),
          edge(b, a).
        |]

    it "can render a relation with multiple clauses" $ do
      let prog = do
            Predicate edge <- typeDef @Edge In
            Predicate reachable <- typeDef @Reachable Out
            let a = Var "a"
                b = Var "b"
                c = Var "c"
            reachable(a, b) |- edge(a, b)
            reachable(a, b) |- do
              edge(a, c)
              reachable(c, b)
      prog ==> [text|
        .decl edge(t1: symbol, t2: symbol)
        .input edge
        .decl reachable(t1: symbol, t2: symbol)
        .output reachable
        reachable(a, b) :-
          edge(a, b).
        reachable(a, b) :-
          edge(a, c),
          reachable(c, b).
        |]

    it "can render a mix of and- and or- clauses correctly" $ do
      let prog = do
            Predicate edge <- typeDef @Edge In
            Predicate reachable <- typeDef @Reachable Out
            let a = Var "a"
                b = Var "b"
                c = Var "c"
            reachable(a, b) |- do
              edge(a, c) <|> edge(a, b)
              reachable(c, b)
      prog ==> [text|
        .decl edge(t1: symbol, t2: symbol)
        .input edge
        .decl reachable(t1: symbol, t2: symbol)
        .output reachable
        reachable(a, b) :-
          (edge(a, c);
          edge(a, b)),
          reachable(c, b).
        |]

    it "can render a logical negation in rule block" pending

{- TODO convert to test
   TODO "internal" fact
  Predicate edge <- typeDef @Edge In
  Predicate reachable <- typeDef @Reachable Out

  reachable("a", "b") |- do
    edge("a", "b")
  reachable ("a", "b") |- do
    edge("a", "c")
    reachable("c", "b")
-}
