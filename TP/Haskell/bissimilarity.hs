{-# LANGUAGE BangPatterns #-}

import qualified Data.Map as M
import qualified Data.Maybe as May
import qualified Data.Set as S
import Data.List (nub)

type State = Integer
type Name = String

type LTS = M.Map State (S.Set (Name, State))

lts :: LTS
lts = M.fromList [
    (1, S.fromList [("a", 2), ("a", 3)]),
    (2, S.fromList [("b", 1), ("a", 3)]),
    (3, S.fromList [("a", 3), ("b", 1)]),

    (4, S.fromList [("a", 5)]),
    (5, S.fromList [("a", 5), ("b", 6)]),
    (6, S.fromList [("a", 5)]),

    (7, S.fromList [("a", 8)]),
    (8, S.fromList [("a", 8), ("b", 7)]),

    (9, S.empty)
    ]

-- States reachable from an LTS via a certain label.
next :: LTS -> State -> Name -> S.Set State
next lts s n = May.fromMaybe S.empty $ do
    labelsToStateSet <- M.lookup s lts
    return $ S.map snd $ S.filter (\(name, _) -> name == n) labelsToStateSet

-- Get all the labels used by a state's transitions.
labelsFromState :: LTS -> State -> S.Set Name
labelsFromState lts s = May.fromMaybe S.empty $ do
    labelsToStateSet <- M.lookup s lts
    return $ S.map fst labelsToStateSet

extendBissim :: LTS -> State -> State -> S.Set (State, State)
extendBissim lts s t =
    let labelsFromS = labelsFromState lts s
        -- Implication as disjunction:
        -- there exist transitions labeled "lab" from state s => there must also exist "lab" transitions for t
        pred set1 set2 = null set1 || not (null set2)
    in if all (\lab -> pred (next lts s lab) (next lts t lab)) labelsFromS
            then S.fromList [(s', t') | lab <- S.toList labelsFromS
                                      , s' <- S.toList $ next lts s lab
                                      , t' <- S.toList $ next lts t lab]
            else mempty

bissimulation :: LTS -> LTS -> State -> State -> S.Set (State, State)
bissimulation l1 l2 p q = helper [(p,q)] (S.fromList [(p, q)])
    where
        helper [] set = set
        helper ((s, t) : rest) !set =
            let newPairs, newPairs' :: S.Set (State, State)
                newPairs = extendBissim l1 s t
                -- Necessário inverter ordem dos pares que resultam desta alternativa.
                -- Ver exercício 1 da ficha 2 - quando se verificam alternativas de
                -- (a, b), e se deu o passo primeiro em b, os pares (a', b') podem
                -- ser considerados em qualquer ordem - (a', b'), (b', a'), mas a função de fecho
                -- transitivo abaixo tratará de calcular (b', a') por nós.
                newPairs' = S.map (\(a, b) -> (b, a))$ extendBissim l2 t s
                extension = newPairs `S.union` newPairs'
            in case (null newPairs || null newPairs', extension `S.isSubsetOf` set) of
                    (True, _) -> S.empty
                    (_, True) -> set
                    (_, _)    -> helper (S.toList extension ++ rest) (set `S.union` extension)

transitiveClosure :: Ord a => S.Set (a, a) -> S.Set (a, a)
transitiveClosure closure = helper closure'
    where
        closureList = S.toList closure
        reflexive = S.fromList $ [(a, a) | (a, _) <- closureList]
        symmetric = S.fromList $ [(b, a) | (a, b) <- closureList]
        closure' = S.unions [closure, reflexive, symmetric]

        helper :: Ord a => S.Set (a, a) -> S.Set (a, a)
        helper set
            | set == closureUntilNow = set
            | otherwise              = transitiveClosure closureUntilNow
            where
                list = S.toList set
                closureUntilNow =
                    S.unions [
                        set,
                        S.fromList [(a, c) | (a, b) <- list, (b', c) <- list, b == b'],
                        S.fromList [(c, a) | (a, b) <- list, (b', c) <- list, b == b']
                    ]