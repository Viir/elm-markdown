module BlockTransformTests exposing (suite)

import Dict
import Expect
import Markdown.Block as Block exposing (..)
import Test exposing (..)


resolveLinkInInline : Inline -> Result String Inline
resolveLinkInInline inline =
    case inline of
        Link destination title inlines ->
            destination
                |> lookupLink
                |> Result.map (\resolvedLink -> Link resolvedLink title inlines)

        _ ->
            Ok inline


lookupLink : String -> Result String String
lookupLink key =
    case key of
        "elm-lang" ->
            Ok "https://elm-lang.org"

        _ ->
            Err <| "Couldn't find key " ++ key


suite : Test
suite =
    only <|
        describe "transform blocks"
            [ test "map links" <|
                \() ->
                    let
                        httpLinksToHttps : String -> String
                        httpLinksToHttps =
                            String.replace "http://" "https://"
                    in
                    [ Paragraph
                        [ Link "http://elm-lang.org" Nothing [ Text "elm-lang homepage" ]
                        ]
                    ]
                        |> Block.mapInlines
                            (\inline ->
                                case inline of
                                    Link destination title inlines ->
                                        Link (httpLinksToHttps destination) title inlines

                                    _ ->
                                        inline
                            )
                        |> Expect.equal
                            [ Paragraph
                                [ Link "https://elm-lang.org" Nothing [ Text "elm-lang homepage" ]
                                ]
                            ]
            , test "validate links - valid" <|
                \() ->
                    [ Paragraph
                        [ Link "elm-lang" Nothing [ Text "elm-lang homepage" ]
                        ]
                    ]
                        |> Block.validateMapInlines resolveLinkInInline
                        |> Expect.equal
                            (Ok
                                [ Paragraph
                                    [ Link "https://elm-lang.org" Nothing [ Text "elm-lang homepage" ]
                                    ]
                                ]
                            )
            , test "validate links - invalid" <|
                \() ->
                    [ Paragraph
                        [ Link "angular" Nothing [ Text "elm-lang homepage" ]
                        ]
                    ]
                        |> Block.validateMapInlines resolveLinkInInline
                        |> Expect.equal (Err [ "Couldn't find key angular" ])
            , test "add slugs" <|
                \() ->
                    let
                        gatherHeadingOccurences : List Block -> ( Dict.Dict String Int, List (BlockWithMeta (Maybe String)) )
                        gatherHeadingOccurences =
                            Block.mapAccuml
                                (\soFar block ->
                                    case block of
                                        Heading level inlines ->
                                            let
                                                inlineText : String
                                                inlineText =
                                                    Block.extractInlineText inlines

                                                occurenceModifier : String
                                                occurenceModifier =
                                                    soFar
                                                        |> Dict.get inlineText
                                                        |> Maybe.map String.fromInt
                                                        |> Maybe.withDefault ""
                                            in
                                            ( soFar |> trackOccurence inlineText
                                            , BlockWithMeta (Heading level inlines) (Just (inlineText ++ occurenceModifier))
                                            )

                                        _ ->
                                            ( soFar
                                            , BlockWithMeta block Nothing
                                            )
                                )
                                Dict.empty

                        trackOccurence : String -> Dict.Dict String Int -> Dict.Dict String Int
                        trackOccurence value occurences =
                            occurences
                                |> Dict.update value
                                    (\maybeOccurence ->
                                        case maybeOccurence of
                                            Just count ->
                                                Just <| count + 1

                                            Nothing ->
                                                Just 1
                                    )
                    in
                    [ Heading H1 [ Text "foo" ]
                    , Heading H1 [ Text "bar" ]
                    , Heading H1 [ Text "foo" ]
                    ]
                        |> gatherHeadingOccurences
                        |> Expect.equal
                            ( Dict.fromList
                                [ ( "bar", 1 )
                                , ( "foo", 2 )
                                ]
                            , [ BlockWithMeta (Heading H1 [ Text "foo" ]) (Just "foo")
                              , BlockWithMeta (Heading H1 [ Text "bar" ]) (Just "bar")
                              , BlockWithMeta (Heading H1 [ Text "foo" ]) (Just "foo1")
                              ]
                            )
            ]


type BlockWithMeta meta
    = BlockWithMeta Block meta
