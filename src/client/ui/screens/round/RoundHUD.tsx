import { useFlameworkDependency } from "@rbxts/flamework-react-utils";
import React, { useEffect, useState } from "@rbxts/react";
import { Players } from "@rbxts/services";
import { CharacterController, TurfTracker } from "client/controllers";
import { Events } from "client/network";
import GameClock from "client/ui/elements/GameClock";
import ProgressBar from "client/ui/elements/ProgressBar";
import { BlockGrid } from "shared/modules";
import ToolDisplay from "./ToolDisplay";
import ResourceDisplay from "./ResourceDisplay";

const player = Players.LocalPlayer;

interface RoundHUDProps {
	team1: Team;
	team2: Team;
}

const RoundHUD = (props: RoundHUDProps): React.Element => {
	const [time, setTime] = useState(0);
	const [phaseName, setPhaseName] = useState("Waiting for Players");

	const turfTracker = useFlameworkDependency<TurfTracker>();
	const [teamTurf, setTeamTurf] = useState(turfTracker.getTeamTurf(player.Team));

	const characterController = useFlameworkDependency<CharacterController>();

	useEffect(() => {
		const connections: Array<RBXScriptConnection> = [
			Events.SetGameClock.connect((time, phaseName) => {
				setTime(time);
				setPhaseName(phaseName);
			}),

			turfTracker.TurfChanged.Connect(() => setTeamTurf(turfTracker.getTeamTurf(player.Team))),
		];

		return () => connections.forEach((connection) => connection.Disconnect());
	}, []);

	useEffect(() => {
		if (time <= 0) return;
		const interval = task.delay(1, () => setTime(time - 1));
		return () => task.cancel(interval);
	}, [time]);

	const myTeamColor = player.Team === props.team1 ? props.team1.TeamColor.Color : props.team2.TeamColor.Color;
	const enemyTeamColor = player.Team === props.team1 ? props.team2.TeamColor.Color : props.team1.TeamColor.Color;

	return (
		<screengui IgnoreGuiInset={true}>
			<GameClock time={time} message={phaseName}>
				<ProgressBar
					anchorPoint={new Vector2(0.5, 0)}
					backgroundColor={enemyTeamColor}
					position={UDim2.fromScale(0.5, 1)}
					size={UDim2.fromScale(1, 0.25)}
					progressColor={myTeamColor}
					font={Enum.Font.Arcade}
					textColor={new Color3(1, 1, 1)}
					textVisible={true}
					textAlignment="Progress"
					value={teamTurf}
					maxValue={BlockGrid.DIMENSIONS.X}
				/>
			</GameClock>
			<frame
				AnchorPoint={new Vector2(0.5, 1)}
				BackgroundTransparency={1}
				Position={UDim2.fromScale(0.5, 1)}
				Size={UDim2.fromScale(1, 0.08)}
			>
				<ToolDisplay characterController={characterController} />
				<ResourceDisplay characterController={characterController} />
			</frame>
		</screengui>
	);
};

export default RoundHUD;
