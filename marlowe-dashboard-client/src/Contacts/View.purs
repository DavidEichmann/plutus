module Contacts.View
  ( contactsCard
  , walletIdTip
  ) where

import Prelude hiding (div)
import Clipboard (Action(..)) as Clipboard
import Css as Css
import Data.Lens (view, (^.))
import Data.Map (isEmpty, toUnfoldable)
import Data.Maybe (Maybe(..), isJust)
import Data.Newtype (unwrap)
import Data.Tuple.Nested ((/\))
import Data.UUID (toString) as UUID
import Halogen.Css (classNames)
import Halogen.HTML (HTML, a, button, div, h2, h3, li, p, span, text, ul)
import Halogen.HTML.Events.Extra (onClick_)
import Halogen.HTML.Properties (disabled)
import InputField.Lenses (_value)
import InputField.State (validate)
import InputField.Types (State) as InputField
import InputField.View (renderInput)
import Material.Icons (Icon(..)) as Icon
import Material.Icons (icon_)
import Contacts.Lenses (_cardSection, _companionAppId, _walletIdInput, _walletLibrary, _walletNickname, _walletNicknameInput)
import Contacts.Types (Action(..), CardSection(..), State, WalletDetails, WalletIdError, WalletLibrary, WalletNicknameError)
import Component.Label.View as Label
import Component.WalletId.View as WalletId

contactsCard :: forall p. WalletDetails -> State -> HTML p Action
contactsCard currentWallet state =
  let
    walletLibrary = state ^. _walletLibrary

    cardSection = state ^. _cardSection

    walletNicknameInput = state ^. _walletNicknameInput

    walletIdInput = state ^. _walletIdInput
  in
    div
      [ classNames [ "h-full", "grid", "grid-rows-auto-auto-1fr-auto", "divide-y", "divide-gray" ] ]
      $ [ h2
            [ classNames Css.cardHeader ]
            [ text "Contacts" ]
        , contactsBreadcrumb cardSection
        ]
      <> case cardSection of
          Home -> walletLibraryCard walletLibrary
          ViewWallet walletDetails -> walletDetailsCard currentWallet walletDetails
          NewWallet mTokenName -> newWalletCard walletNicknameInput walletIdInput mTokenName

contactsBreadcrumb :: forall p. CardSection -> HTML p Action
contactsBreadcrumb cardSection =
  div
    [ classNames [ "overflow-x-auto", "flex", "align-baseline", "px-4", "gap-1", "text-xs" ] ] case cardSection of
    Home -> [ activeItem "Home" ]
    ViewWallet walletDetails ->
      [ previousItem "Home" Home
      , arrow
      , activeItem $ walletDetails ^. _walletNickname
      ]
    NewWallet mTokenName ->
      [ previousItem "Home" Home
      , arrow
      , case mTokenName of
          Nothing -> activeItem "New Contact"
          Just tokenName -> activeItem $ "New Contact for " <> tokenName <> " Role"
      ]
  where
  activeItem itemText =
    span
      [ classNames [ "whitespace-nowrap", "py-2.5", "border-black", "border-b-2", "font-semibold" ] ]
      [ text itemText ]

  previousItem itemText stage =
    a
      [ classNames [ "whitespace-nowrap", "py-2.5", "text-purple", "border-transparent", "border-b-2", "hover:border-purple", "font-semibold" ]
      , onClick_ $ SetCardSection stage
      ]
      [ text itemText ]

  arrow = span [ classNames [ "mt-2" ] ] [ icon_ Icon.Next ]

walletLibraryCard :: forall p. WalletLibrary -> Array (HTML p Action)
walletLibraryCard walletLibrary =
  [ if isEmpty walletLibrary then
      -- If you're here, the walletLibrary can't be empty, because at least your own wallet will
      -- be in there. But that might change when we have real wallet integration, and it's easy
      -- to forget cases like these, so it seems sensible to code for it in case.
      p [ classNames [ "p-4" ] ] [ text "You do not have any contacts." ]
    else
      ul [ classNames [ "divide-y", "divide-gray" ] ] $ contactLi <$> toUnfoldable walletLibrary
  , button
      [ classNames $ Css.primaryButton <> Css.withIcon Icon.NewContact <> Css.fixedBottomRight
      , onClick_ $ SetCardSection $ NewWallet Nothing
      ]
      [ text "New contact" ]
  ]
  where
  contactLi (nickname /\ walletDetails) =
    li
      [ classNames [ "px-4", "py-2", "hover:cursor-pointer", "hover:text-purple" ]
      , onClick_ $ SetCardSection $ ViewWallet walletDetails
      ]
      [ text nickname ]

walletDetailsCard :: forall p. WalletDetails -> WalletDetails -> Array (HTML p Action)
walletDetailsCard currentWallet walletDetails =
  let
    walletNickname = walletDetails ^. _walletNickname

    companionAppId = walletDetails ^. _companionAppId

    companionAppIdString = UUID.toString $ unwrap companionAppId

    isCurrentWallet = walletNickname == currentWallet ^. _walletNickname

    copyWalletId = (ClipboardAction <<< Clipboard.CopyToClipboard <<< UUID.toString <<< unwrap)
  in
    [ div [ classNames [ "space-y-4", "p-4" ] ]
        [ h3
            [ classNames [ "text-lg", "font-semibold" ] ]
            [ text walletNickname ]
        , copyWalletId
            <$> WalletId.render
                WalletId.defaultInput
                  { label = "Demo wallet key"
                  , value = companionAppId
                  }
        , walletIdTip
        ]
    , div
        [ classNames [ "flex", "gap-4", "p-4" ] ]
        [ a
            [ classNames $ Css.button <> [ "text-center" ]
            , onClick_ $ SetCardSection Home
            ]
            [ text "Back" ]
        , if isCurrentWallet then
            span
              [ classNames $ Css.button <> [ "flex-1", "text-center", "border-2", "border-green", "text-green" ] ]
              [ text "Using this wallet" ]
          else
            button
              [ classNames $ Css.primaryButton <> [ "flex-1", "text-center" ]
              , onClick_ $ ConnectWallet walletNickname companionAppId
              ]
              [ text "Connect wallet" ]
        ]
    ]

newWalletCard :: forall p. InputField.State WalletNicknameError -> InputField.State WalletIdError -> Maybe String -> Array (HTML p Action)
newWalletCard walletNicknameInput walletIdInput mTokenName =
  let
    walletNickname = view _value walletNicknameInput

    walletIdString = view _value walletIdInput

    walletNicknameInputDisplayOptions =
      { additionalCss: mempty
      , id_: "newWalletNickname"
      , placeholder: "Nickname"
      , readOnly: false
      , numberFormat: Nothing
      , valueOptions: mempty
      , after: Nothing
      , before:
          Just
            $ Label.render
                Label.defaultInput
                  { for = "newWalletNickname", text = "Wallet nickname" }
      }

    walletIdInputDisplayOptions =
      { additionalCss: mempty
      , id_: "newWalletId"
      , placeholder: "Wallet ID"
      , readOnly: false
      , numberFormat: Nothing
      , valueOptions: mempty
      , after: Nothing
      , before:
          Just
            $ Label.render
                Label.defaultInput
                  { for = "newWalletId", text = "Wallet nickname" }
      }
  in
    [ div [ classNames [ "space-y-4", "p-4" ] ]
        [ WalletNicknameInputAction <$> renderInput walletNicknameInputDisplayOptions walletNicknameInput
        , WalletIdInputAction <$> renderInput walletIdInputDisplayOptions walletIdInput
        ]
    , div
        [ classNames [ "flex", "gap-4", "p-4" ] ]
        [ a
            [ classNames $ Css.button <> [ "flex-1", "text-center" ]
            , onClick_ case mTokenName of
                Just _ -> CancelNewContactForRole
                Nothing -> SetCardSection Home
            ]
            [ text "Back" ]
        , button
            [ classNames $ Css.primaryButton <> [ "flex-1" ]
            , disabled $ isJust (validate walletNicknameInput) || isJust (validate walletIdInput)
            , onClick_ $ SaveWallet mTokenName
            ]
            [ text "Save" ]
        ]
    ]

walletIdTip :: forall p a. HTML p a
walletIdTip =
  p
    [ classNames [ "text-xs", "font-semibold" ] ]
    [ text "Tip: Copy and share your demo wallet ID with others so they can add you to their contracts" ]
