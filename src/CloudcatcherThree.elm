module CloudcatcherThree where

import Effects exposing (Effects, Never)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, targetValue, on)
import Http
import Json.Decode as Json exposing(Decoder, (:=))
import Task exposing (andThen, Task)
import Dict

-- MODEL

type alias PodcastDict = Dict.Dict Int Podcast

type alias Podcast =
    { name : String, 
      aritstName : String, 
      image : String,
      id : Int, 
      feedUrl : String
    }

type alias Model = 
    { podcasts : PodcastDict,
      visiblePodcasts : List Int,
      searchTerm : String,
      selectedPodcast: Maybe Int
    }

type alias ModelOutput = 
    { podcasts : List Podcast,
      visiblePodcasts : List Int,
      searchTerm : String,
      selectedPodcast: Maybe Int
    }

emptyModel : Model
emptyModel = Model Dict.empty [] "" Nothing

-- UPDATE

type Action 
    = NoOp 
    | AddPodcasts PodcastDict 
    | UpdateSearchInput String
    | SubmitSearch String
    | SelectPodcast (Maybe Int)

update : Action -> Model -> (Model, Effects Action)
update action model =
   case action of

    NoOp ->
        ( model
        , Effects.none 
        )

    AddPodcasts new -> 
        ({ model | 
            podcasts = Dict.union new model.podcasts,
            visiblePodcasts = Dict.keys new
         }
         , Effects.none
        )

    UpdateSearchInput term ->
        ({ model | searchTerm = term }
         , Effects.none
        )

    SubmitSearch term -> 
        ({ model | searchTerm = term }
         , getSearchResults term
        )  

    SelectPodcast id ->
        ({ model | selectedPodcast = id }
         , Effects.none
        )

-- EFFECTS

handleSearchResults : Maybe (List Podcast) -> Action
handleSearchResults podcast = 
    case podcast of
        Just e -> AddPodcasts (listToDict .id e)
        Nothing -> AddPodcasts Dict.empty

getSearchResults : String -> Effects Action
getSearchResults query = 
  Http.get podcasts (searchUrl query)
    |> Task.toMaybe
    |> Task.map handleSearchResults
    |> Effects.task

podcast : Json.Decoder (Podcast)
podcast = 
    Json.object5 Podcast
        ("name" := Json.string )
        ("artistName" := Json.string )
        ("image" := Json.string )
        ("id" := Json.int ) 
        ("feedUrl" := Json.string )

podcasts : Json.Decoder (List Podcast)
podcasts = "results" := Json.list podcast

-- VIEW

-- RIGHT

--podcastDisplay : Signal.Address Action -> Podcast -> Bool -> Html
--podcastDisplay address podcast subscribed = 
--    div [ class "page-header" ] [
--        h3 [] 
--           [ text podcast.name, small [] [ text podcast.aritstName ] ],
--        img [ src podcast.image ] [],
--        div [ class "btn-toolbar well" ] 
--            [ button [ class (if subscribed then "btn active" else "btn btn-primary")
--                     , onClick address (handleClick podcast subscribed) 
--                     ]  
--                     [ text (if subscribed then "Unsubscribe" else "Subscribe") ]
--            ]
--    ]

--rightColumnDisplay : Signal.Address Action -> Maybe Podcast -> List Int -> List Episode -> Html
--rightColumnDisplay address podcast subscriptionIds episodes = 
--  div [] 
--      [ 
--          case podcast of
--            Just value -> (podcastDisplay address value) (List.member value.id subscriptionIds) episodes
--            Nothing -> div [][ text "Select a podcast" ]
--      ]


-- LEFT

searchForm: Signal.Address Action -> String -> Html
searchForm address term = 
    div [ class "form-inline" ]
        [ input 
            [ type' "text",
              class "form-control",
              placeholder "Search for a podcast",
              value term,
              name "search",
              autofocus True,
              onInput address UpdateSearchInput
            ]
            [ ]
        , button 
            [ class "btn btn-primary"
            , onClick address (SubmitSearch term)
            ] 
            [ text "Search" ]
        ]

podcastListItem : Signal.Address Action -> Bool -> Podcast-> Html
podcastListItem address isSelected podcast = 
  let
    listItemStyle = if isSelected then "list-group-item active" else "list-group-item"
  in
    a [ href "#",
        onClick address (SelectPodcast (Just podcast.id)), 
        class listItemStyle
      ]
      [ text podcast.name ]

podcastList: Signal.Address Action -> List Podcast -> Maybe Int -> Html
podcastList address entries selectedPodcast = 
  let
    isSelected e = e.id == Maybe.withDefault 0 selectedPodcast
    entryItems = List.map (\e -> (podcastListItem address (isSelected e) e)) (List.sortBy .name entries)
  in
    div [ class "list-group" ] entryItems

-- MAIN

view : Signal.Address Action -> Model -> Html
view address model = 
  let
    visiblePodcasts = List.filterMap (\v -> Dict.get v model.podcasts) model.visiblePodcasts
    createPodcastList = podcastList address visiblePodcasts model.selectedPodcast
    createSearchForm = searchForm address model.searchTerm
  in
    div [ class "container-fluid" ] 
        [ 
            div [ class "col-md-6 col-sm-6 col-lg-6"]
            [ createSearchForm,
              createPodcastList
            ]
        ]

-- UTILS

(=>) = (,)

onInput : Signal.Address a -> (String -> a) -> Attribute
onInput address f =
  on "input" targetValue (\v -> Signal.message address (f v))

listToDict : (a -> comparable) -> List a -> Dict.Dict comparable a
listToDict getKey values = Dict.fromList (List.map (\v -> (getKey v, v)) values)

searchUrl : String -> String
searchUrl term = 
  Http.url "http://127.0.0.1:9000/v1/podcasts"
    ["term" => term]

-- WIRE UP

-- interactions with localStorage to save the model
inbox : Signal.Mailbox Action
inbox =
  Signal.mailbox NoOp

-- actions from user input
actions : Signal.Mailbox Action
actions =
  Signal.mailbox NoOp