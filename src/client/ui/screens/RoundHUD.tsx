import { Dependency } from "@flamework/core";
import React, { useEffect, useState } from "@rbxts/react";
import { Players } from "@rbxts/services";
import { TurfTracker } from "client/controllers";
import { Events } from "client/network";
import ProgressBar from "client/ui/elements";
import { BlockGrid } from "shared/modules";

const player = Players.LocalPlayer;

const formatTime = (time: number): string => {
	const minutes = math.floor(time / 60);
	const seconds = time % 60;
	return string.format("%02d:%02d", minutes, seconds);
};

const RoundHUD = (): React.Element => {
	const [time, setTime] = useState(0);
	const [phaseName, setPhaseName] = useState("Waiting for Players");
	const [teamTurf, setTeamTurf] = useState(0);

	useEffect(() => {
		const connections: Array<RBXScriptConnection> = [];

		connections.push(
			Events.SetGameClock.connect((time, phaseName) => {
				setTime(time);
				setPhaseName(phaseName);
			}),
		);

		const turfTracker = Dependency<TurfTracker>();
		connections.push(turfTracker.TurfChanged.Connect(() => setTeamTurf(turfTracker.getTeamTurf(player.Team))));

		return () => connections.forEach((connection) => connection.Disconnect());
	}, []);

	useEffect(() => {
		if (time <= 0) return;
		const interval = task.delay(1, () => setTime(time - 1));
		return () => task.cancel(interval);
	}, [time]);

	return (
		<frame
			AnchorPoint={new Vector2(0.5, 0)}
			BackgroundColor3={new Color3(0, 0, 0)}
			BackgroundTransparency={0.75}
			BorderSizePixel={0}
			Position={UDim2.fromScale(0.5, 0)}
			Size={UDim2.fromScale(0, 0.15)}
		>
			<textlabel
				AnchorPoint={new Vector2(0.5, 0)}
				BackgroundTransparency={1}
				Position={UDim2.fromScale(0.5, 0)}
				Size={UDim2.fromScale(1, 0.6)}
				Font={Enum.Font.Arcade}
				RichText={true}
				Text={`<b>${formatTime(time)}</b>`}
				TextColor3={new Color3(1, 1, 1)}
				TextScaled={true}
			/>
			<textlabel
				AnchorPoint={new Vector2(0.5, 0)}
				BackgroundTransparency={1}
				Position={UDim2.fromScale(0.5, 0.55)}
				Size={UDim2.fromScale(1, 0.2)}
				Font={Enum.Font.Arcade}
				Text={phaseName}
				TextColor3={new Color3(1, 1, 1)}
				TextScaled={true}
			/>
			<uiaspectratioconstraint
				AspectRatio={2}
				AspectType={Enum.AspectType.ScaleWithParentSize}
				DominantAxis={Enum.DominantAxis.Height}
			/>
			<ProgressBar
				anchorPoint={new Vector2(0.5, 1)}
				backgroundColor={new BrickColor("Bright red").Color}
				borderSizePixel={0}
				position={UDim2.fromScale(0.5, 1)}
				size={UDim2.fromScale(1, 0.2)}
				progressColor={new BrickColor("Bright blue").Color}
				font={Enum.Font.Arcade}
				textColor={new Color3(1, 1, 1)}
				value={teamTurf}
				maxValue={BlockGrid.DIMENSIONS.X}
			/>
		</frame>
	);
};

export default RoundHUD;
