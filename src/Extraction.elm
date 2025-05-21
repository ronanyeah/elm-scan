module Extraction exposing (rule)

import Dict exposing (Dict)
import Elm.Syntax.Declaration as Declaration exposing (Declaration)
import Elm.Syntax.Node as Node exposing (Node)
import Elm.Syntax.TypeAnnotation exposing (TypeAnnotation(..))
import Json.Encode as JE
import Maybe.Extra exposing (unwrap)
import Result.Extra
import Review.Rule as Rule exposing (Rule)


type alias Def =
    { name : String
    , type_ : String
    , data : String
    }


type alias ProjectContext =
    Dict String (List Def)


type alias ModuleContext =
    { declarations : List Def
    }


rule : Rule
rule =
    Rule.newProjectRuleSchema "Extraction" Dict.empty
        |> Rule.withModuleVisitor moduleVisitor
        |> Rule.withModuleContextUsingContextCreator
            { fromProjectToModule = fromProjectToModule
            , fromModuleToProject = fromModuleToProject
            , foldProjectContexts = foldProjectContexts
            }
        |> Rule.withDataExtractor dataExtractor
        |> Rule.fromProjectRuleSchema


moduleVisitor : Rule.ModuleRuleSchema schemaState ModuleContext -> Rule.ModuleRuleSchema { schemaState | hasAtLeastOneVisitor : () } ModuleContext
moduleVisitor schema =
    schema
        |> Rule.withDeclarationListVisitor (\node context -> ( [], declarationListVisitor node context ))


fromProjectToModule : Rule.ContextCreator ProjectContext ModuleContext
fromProjectToModule =
    Rule.initContextCreator
        (\_ ->
            { declarations = []
            }
        )


fromModuleToProject : Rule.ContextCreator ModuleContext ProjectContext
fromModuleToProject =
    Rule.initContextCreator
        (\moduleName moduleContext ->
            Dict.singleton (String.join "." moduleName) moduleContext.declarations
        )
        |> Rule.withModuleName


foldProjectContexts : ProjectContext -> ProjectContext -> ProjectContext
foldProjectContexts =
    Dict.union


declarationListVisitor : List (Node Declaration) -> ModuleContext -> ModuleContext
declarationListVisitor nodes context =
    { context
        | declarations =
            nodes
                |> List.map
                    (\node ->
                        case Node.value node of
                            Declaration.FunctionDeclaration { declaration, signature } ->
                                let
                                    data =
                                        signature
                                            |> unwrap "NO_SIG"
                                                (Node.value
                                                    >> .typeAnnotation
                                                    >> typeName
                                                    >> Result.Extra.unpack
                                                        ((++) "BAD_PARSE_")
                                                        identity
                                                )
                                in
                                { name =
                                    declaration
                                        |> Node.value
                                        |> .name
                                        |> Node.value
                                , type_ =
                                    signature
                                        |> Maybe.map
                                            (Node.value
                                                >> .typeAnnotation
                                            )
                                        |> unwrap "???"
                                            (\sig ->
                                                case Node.value sig of
                                                    Typed _ _ ->
                                                        "value"

                                                    _ ->
                                                        "function"
                                            )
                                , data = data
                                }

                            Declaration.AliasDeclaration x ->
                                { name =
                                    x
                                        |> .name
                                        |> Node.value
                                , type_ =
                                    case Node.value x.typeAnnotation of
                                        Record _ ->
                                            "record"

                                        _ ->
                                            "alias"
                                , data =
                                    typeName x.typeAnnotation
                                        |> Result.Extra.unpack identity identity
                                }

                            Declaration.CustomTypeDeclaration x ->
                                { name =
                                    x
                                        |> .name
                                        |> Node.value
                                , type_ = "enum"
                                , data =
                                    x.constructors
                                        |> List.map (Node.value >> .name >> Node.value)
                                        |> String.join " | "
                                }

                            Declaration.PortDeclaration p ->
                                { name =
                                    p
                                        |> .name
                                        |> Node.value
                                , type_ = "port"
                                , data = "???"
                                }

                            Declaration.InfixDeclaration _ ->
                                { name = "???"
                                , type_ = "infix"
                                , data = "???"
                                }

                            Declaration.Destructuring _ _ ->
                                { name = "???"
                                , type_ = "destructure"
                                , data = "???"
                                }
                    )
    }


dataExtractor : ProjectContext -> JE.Value
dataExtractor declarations =
    JE.dict identity
        (JE.list
            (\def ->
                def.name
                    ++ " : "
                    ++ def.type_
                    ++ " : "
                    ++ def.data
                    |> JE.string
            )
        )
        declarations


typeName : Node.Node TypeAnnotation -> Result String String
typeName t =
    case Node.value t of
        FunctionTypeAnnotation n1 n2 ->
            Result.map2
                (\a b ->
                    a
                        ++ " -> "
                        ++ b
                )
                (typeName n1
                    |> Result.map
                        (\x ->
                            if String.contains "->" x then
                                "("
                                    ++ x
                                    ++ ")"

                            else
                                x
                        )
                )
                (typeName n2)

        GenericType val ->
            Ok val

        Typed typ args ->
            case Tuple.second (Node.value typ) of
                "String" ->
                    Ok "String"

                "Bool" ->
                    Ok "Bool"

                "Value" ->
                    Ok "Json.Value"

                "Int" ->
                    Ok "Int"

                "Float" ->
                    Ok "Float"

                "Maybe" ->
                    args
                        |> List.head
                        |> Result.fromMaybe "no maybe arg"
                        |> Result.andThen typeName
                        |> Result.map
                            (\val ->
                                "Maybe " ++ val
                            )

                "List" ->
                    args
                        |> List.head
                        |> Result.fromMaybe "no list arg"
                        |> Result.andThen typeName
                        |> Result.map
                            (\val ->
                                "List " ++ val
                            )

                "Array" ->
                    args
                        |> List.head
                        |> Result.fromMaybe "no array arg"
                        |> Result.andThen typeName
                        |> Result.map
                            (\val ->
                                "Array " ++ val
                            )

                a ->
                    if List.isEmpty args then
                        Ok a

                    else
                        args
                            |> List.map typeName
                            |> Result.Extra.combine
                            |> Result.map
                                (String.join " "
                                    >> (++) (a ++ " ")
                                )

        Unit ->
            Ok "()"

        Tupled xs ->
            xs
                |> List.map typeName
                |> Result.Extra.combine
                |> Result.map
                    (\val ->
                        "(" ++ String.join ", " val ++ ")"
                    )

        Record xs ->
            recordEntries xs
                |> Result.map
                    (\val ->
                        "{ " ++ (val |> String.join ", ") ++ " }"
                    )

        GenericRecord _ _ ->
            Err "TodoGenericRecord_"


recordEntries : List (Node.Node ( Node.Node String, Node.Node TypeAnnotation )) -> Result String (List String)
recordEntries xs =
    xs
        |> List.map Node.value
        |> List.map
            (\( n, t ) ->
                typeName t
                    |> Result.map
                        (\val ->
                            Node.value n ++ ": " ++ val
                        )
            )
        |> Result.Extra.combine
