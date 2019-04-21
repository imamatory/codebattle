import React, { Component } from 'react';
import _ from 'lodash';
import { connect } from 'react-redux';
import { ToastContainer, toast } from 'react-toastify';
import { Alert } from 'react-bootstrap';
import * as selectors from '../selectors';
import GameStatusCodes from '../config/gameStatusCodes';
import Toast from '../components/Toast';
import ActionsAfterGame from '../components/Toast/ActionsAfterGame';
import CloseButton from '../components/Toast/CloseButton';
import { updateGameUI as updateGameUIAction } from '../actions';
import { sendRejectToRematch } from '../middlewares/Game';

const toastOptions = {
  hideProgressBar: true,
  position: toast.POSITION.TOP_CENTER,
  autoClose: 3000,
  closeOnClick: false,
  toastClassName: 'toast-container',
  closeButton: <CloseButton />,
};

class NotificationsHandler extends Component {
  componentDidMount() {
    const { gameStatus: { status } } = this.props;

    if (status === GameStatusCodes.gameOver
      || status === GameStatusCodes.rematchInApproval
      || status === GameStatusCodes.rematchRejected) {
      this.showActionsAfterGame();
    }
  }

  componentDidUpdate(prevProps) {
    const {
      gameStatus: {
        solutionStatus, status, checking, rematchState,
      },
      isCurrentUserPlayer,
    } = this.props;

    const isChangeRematchState = prevProps.gameStatus.rematchState !== rematchState;

    if (isCurrentUserPlayer && prevProps.gameStatus.checking && !checking) {
      this.showCheckingStatusMessage(solutionStatus);
    }

    if (status === GameStatusCodes.gameOver && prevProps.gameStatus.status !== status) {
      this.showGameResultMessage();
      this.showActionsAfterGame();
    }

    if (isChangeRematchState && rematchState !== 'none' && rematchState !== 'rejected') {
      this.showActionsAfterGame();
    }
  }

  showCheckingStatusMessage = (solutionStatus) => {
    if (solutionStatus) {
      toast(
        <Toast header="Success">
          <Alert variant="success">Yay! All tests passed!</Alert>
        </Toast>,
      );
    } else {
      toast(
        <Toast header="Failed">
          <Alert variant="error">Oh no, some test has failed!</Alert>
        </Toast>,
      );
    }
  }

  showActionsAfterGame = () => {
    const {
      isCurrentUserPlayer,
      updateGameUI,
      isShowActionsAfterGame,
    } = this.props;

    if (!isCurrentUserPlayer) {
      return;
    }

    if (isShowActionsAfterGame) {
      return;
    }

    toast(
      <Toast header="Next Action">
        <ActionsAfterGame />
      </Toast>,
      {
        autoClose: false,
        onClose: () => {
          updateGameUI({ showToastActionsAfterGame: false });
          sendRejectToRematch();
        },
        onOpen: () => updateGameUI({ showToastActionsAfterGame: true }),
      },
    );
  }

  showGameResultMessage = () => {
    const {
      isCurrentUserPlayer,
      currentUserId,
      players,
    } = this.props;

    const winner = _.find(players, ['game_result', 'won']);

    if (currentUserId === winner.id) {
      toast(
        <Toast header="Success">
          <Alert variant="success">Congratulations! You have won the game!</Alert>
        </Toast>,
      );
      return;
    }

    if (isCurrentUserPlayer) {
      toast(
        <Toast header="Failed">
          <Alert variant="danger">Oh snap! Your opponent has won the game</Alert>
        </Toast>,
      );
      return;
    }

    toast(
      <Toast header="Success">
        <Alert variant="success">
          {`${winner.name} has won the game!`}
        </Alert>
      </Toast>,
    );
  }

  render() {
    return <ToastContainer {...toastOptions} />;
  }
}

const mapStateToProps = (state) => {
  const currentUserId = selectors.currentUserIdSelector(state);
  const players = selectors.gamePlayersSelector(state);
  const isCurrentUserPlayer = _.hasIn(players, currentUserId);
  const isShowActionsAfterGame = state.gameUI.showToastActionsAfterGame;

  return {
    currentUserId,
    players,
    isCurrentUserPlayer,
    isShowActionsAfterGame,
    gameStatus: selectors.gameStatusSelector(state),
  };
};

const mapDispatchToProps = {
  updateGameUI: updateGameUIAction,
};

export default connect(mapStateToProps, mapDispatchToProps)(NotificationsHandler);
