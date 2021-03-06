port module Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Navigation
import LeaderBoard
import Login
import AddRunner

-- model


type alias Model =
  { page : Page
  , leaderBoard : LeaderBoard.Model
  , login : Login.Model
  , runner : AddRunner.Model
  , token : Maybe String
  , loggedIn : Bool
  }


type Page
  = NotFound
  | LeaderBoardPage
  | LoginPage
  | AddRunnerPage


init : Flags -> Navigation.Location -> ( Model, Cmd Msg )
init flags location =
  let
    page =
      hashToPage location.hash

    ( leaderboardInitModel, leaderboardCmd ) =
      LeaderBoard.init

    ( loginInitModel, loginCmd ) =
      Login.init

    ( runnerInitModel, runnerCmd ) =
      AddRunner.init

    initModel =
      { page = page
      , leaderBoard = leaderboardInitModel
      , login = loginInitModel
      , runner = runnerInitModel
      , token = flags.token
      , loggedIn = flags.token /= Nothing
      }

    cmds =
      Cmd.batch
        [ Cmd.map LeaderBoardMsg leaderboardCmd
        , Cmd.map LoginMsg loginCmd
        , Cmd.map RunnerMsg runnerCmd
        ]

  in
    ( initModel, cmds )

-- update


type Msg
  = Navigate Page
  | ChangePage Page
  | LeaderBoardMsg LeaderBoard.Msg
  | LoginMsg Login.Msg
  | RunnerMsg AddRunner.Msg
  | Logout


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  case msg of
    Navigate page ->
      ( model, Navigation.newUrl <| pageToHash page )

    ChangePage page ->
      ({ model
        | page = page
       }
        , Cmd.none
      )

    LeaderBoardMsg msg ->
      let
        ( leaderBoardModel, cmd ) =
          LeaderBoard.update msg model.leaderBoard
      in
        ({ model
          | leaderBoard = leaderBoardModel
         }
         , Cmd.map LeaderBoardMsg cmd
        )

    LoginMsg msg ->
      let
        ( loginModel, cmd, token ) =
          Login.update msg model.login

        loggedIn =
          token /= Nothing

        saveTokenCmd =
          case token of
            Just jwt ->
              saveToken jwt

            Nothing ->
              Cmd.none

      in
        ({ model
         | login = loginModel
         , token = token
         , loggedIn = loggedIn
         }
         , Cmd.batch
            [ Cmd.map LoginMsg cmd
            , saveTokenCmd
            ]
        )

    RunnerMsg msg ->
      let
        ( runnerModel, cmd ) =
          AddRunner.update msg model.runner
      in
        ({ model
         | runner = runnerModel
         }
         , Cmd.map RunnerMsg cmd
        )

    Logout ->
      ( { model
        | token = Nothing
        , loggedIn = False
       }
      , deleteToken ()
      )
-- view


view : Model -> Html Msg
view model =
  let
    page =
      case model.page of
        AddRunnerPage ->
          Html.map RunnerMsg
            ( AddRunner.view model.runner )

        LeaderBoardPage ->
          Html.map LeaderBoardMsg
            ( LeaderBoard.view model.leaderBoard )

        LoginPage ->
          Html.map LoginMsg
            ( Login.view model.login )

        NotFound ->
          div [ class "main" ]
            [ h1 []
              [ text "Page Not Found!" ]
            ]
  in
    div []
      [ pageHeader model
      , page
      ]

authHeaderView : Model -> Html Msg
authHeaderView model =
  if model.loggedIn then
    a [ onClick Logout ]
      [ text "Logout"
      ]
  else
    a [ onClick (Navigate LoginPage) ]
      [ text "Login"
      ]

pageHeader : Model -> Html Msg
pageHeader model =
  header []
    [ a [ onClick (Navigate LeaderBoardPage) ] [ text "Race Results"]
    , ul []
      [ li []
        [ a [ onClick (Navigate AddRunnerPage) ] [ text "Add Runner" ]
        ]
      ]
    , ul []
      [ li []
        [ authHeaderView model ]
        ]
      ]
    ]




-- subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
  let
    leaderBoardSub =
      LeaderBoard.subscriptions model.leaderBoard

    loginSub =
      Login.subscriptions model.login

    runnerSub =
      AddRunner.subscriptions model.runner

  in
    Sub.batch
      [ Sub.map LeaderBoardMsg leaderBoardSub
      , Sub.map LoginMsg loginSub
      , Sub.map RunnerMsg runnerSub
      ]

hashToPage : String -> Page
hashToPage hash =
  case hash of
    "#/" ->
      LeaderBoardPage

    "#login" ->
        LoginPage

    "" ->
      LeaderBoardPage

    "#addRunner" ->
      AddRunnerPage

    _ ->
      NotFound

pageToHash : Page -> String
pageToHash page =
  case page of
    LeaderBoardPage ->
      "#/"

    NotFound ->
      "#notfound"

    LoginPage ->
      "#login"

    AddRunnerPage ->
      "#addRunner"

locationToMessage : Navigation.Location -> Msg
locationToMessage location =
  location.hash
    |> hashToPage
    |> ChangePage

type alias Flags =
  { token : Maybe String
  }

main : Program Flags Model Msg
main =
  Navigation.programWithFlags locationToMessage
    { init = init
    , update = update
    , view = view
    , subscriptions = subscriptions
    }

port saveToken : String -> Cmd msg
port deleteToken : () -> Cmd msg
