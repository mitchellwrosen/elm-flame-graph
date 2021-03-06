module FlameGraph
    exposing
        ( StackFrame(..)
        , fromString
        , view
        )

import Dict
import Html exposing (Html, button, div, span, text)
import Html.Attributes exposing (style, title)
import Html.Events exposing (onClick, onMouseEnter)


type StackFrame
    = StackFrame
        { name : String
        , count : Int
        , children : List StackFrame
        }



-- Render


view :
    (StackFrame -> List StackFrame -> a)
    -> (StackFrame -> List StackFrame -> a)
    -> List StackFrame
    -> Html a
view onBarHover onBarClick frames =
    let
        total : Int
        total =
            frames
                |> List.map
                    (\(StackFrame { count }) -> count)
                |> List.sum
    in
    div
        [ style flameStyles ]
        (List.map
            (\frame ->
                case frame of
                    StackFrame { name, count, children } ->
                        div
                            [ style
                                (( "width"
                                 , toString (toFloat count / toFloat total * 100) ++ "%"
                                 )
                                    :: columnStyles
                                )
                            ]
                            [ span
                                [ style barStyles
                                , title name
                                , onClick (onBarClick frame frames)
                                , onMouseEnter (onBarHover frame frames)
                                ]
                                [ span [ style labelStyles ] [ text name ] ]
                            , view onBarHover onBarClick children
                            ]
            )
            frames
        )


flameStyles =
    [ ( "width", "100%" )
    , ( "position", "relative" )
    , ( "display", "flex" )
    ]


barStyles =
    [ ( "position", "relative" )
    , ( "overflow-x", "hidden" )
    , ( "height", "14px" )
    , ( "border", "1px solid #666" )
    , ( "margin", "1px" )
    ]


columnStyles =
    [ ( "display", "flex" )
    , ( "flex-direction", "column" )
    ]


labelStyles =
    [ ( "font-size", "10px" )
    , ( "position", "absolute" )
    , ( "padding", "0 4px" )
    ]



-- Parse


type alias PreStackFrame =
    { children : List String
    , count : Int
    }


fromString : String -> List StackFrame
fromString =
    preParse >> nest


parseLine : String -> Result String ( List String, Int )
parseLine =
    let
        f : ( List String, String ) -> Result String ( List String, Int )
        f ( initial, last ) =
            last
                |> String.toInt
                |> Result.map
                    (\num -> ( String.split ";" (String.join " " initial), num ))
    in
    String.words
        >> unsnoc
        >> maybe (Err "Unable to split line") f


preParse : String -> List PreStackFrame
preParse =
    let
        f : Result String ( List String, Int ) -> PreStackFrame
        f result =
            case result of
                Ok ( stack, count ) ->
                    { children = stack
                    , count = count
                    }

                Err _ ->
                    { children = []
                    , count = 0
                    }
    in
    String.split "\n"
        >> List.map (parseLine >> f)


nest : List PreStackFrame -> List StackFrame
nest =
    groupBy
        (\{ children } ->
            case List.head children of
                Just name ->
                    name

                Nothing ->
                    ""
        )
        >> List.map
            (\( name, preFrames ) ->
                let
                    count : Int
                    count =
                        preFrames
                            |> List.map .count
                            |> List.sum

                    children : List PreStackFrame
                    children =
                        preFrames
                            |> List.filterMap
                                (\{ children, count } ->
                                    List.tail children
                                        |> Maybe.map
                                            (\remaining ->
                                                { children = remaining
                                                , count = count
                                                }
                                            )
                                )
                in
                StackFrame
                    { name = name
                    , count = count
                    , children = nest children
                    }
            )


groupBy : (a -> comparable) -> List a -> List ( comparable, List a )
groupBy fn =
    List.foldr
        (\x ->
            Dict.update
                (fn x)
                (Maybe.withDefault [] >> cons x >> Just)
        )
        Dict.empty
        >> Dict.toList


cons : a -> List a -> List a
cons =
    (::)


unsnoc : List a -> Maybe ( List a, a )
unsnoc xs =
    case xs of
        [] ->
            Nothing

        x :: xs ->
            case unsnoc xs of
                Nothing ->
                    Just ( [], x )

                Just ( ys, y ) ->
                    Just ( x :: ys, y )


maybe : b -> (a -> b) -> Maybe a -> b
maybe z f mx =
    case mx of
        Nothing ->
            z

        Just x ->
            f x
