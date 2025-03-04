import React, { useEffect, useRef, useState } from "@rbxts/react";
import { Players, StarterGui, TweenService } from "@rbxts/services";
import { useFlameworkDependency } from "@rbxts/flamework-react-utils";
import { CharacterController } from "client/controllers";
import { Events } from "client/network";
import { ChampionStage, GameMap } from "shared/types/workspaceTypes";
import RoundHUD from "./screens/round";

StarterGui.SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false);

const FIELD_OF_VIEW = 70;

const player = Players.LocalPlayer;

const App = (): React.Element => {
	const [inRound, setInRound] = useState(false);
	const [teams, setTeams] = useState<[Team, Team]>([undefined!, undefined!]);
	const gameMapRef = useRef<GameMap>();

	const characterController = useFlameworkDependency<CharacterController>();

	useEffect(() => {
		const connections: Array<RBXScriptConnection> = [
			Events.RoundStarting.connect((team1, team2, gameMap) => {
				setInRound(true);
				setTeams([team1, team2]);
				gameMapRef.current = gameMap as GameMap;
			}),
			Events.RoundEnding.connect((winningTeam, championStageInstance) => {
				setInRound(false);

				const gameMap = gameMapRef.current;
				if (!gameMap) {
					warn("No game map found");
					return;
				}

				const championStage = championStageInstance as ChampionStage;

				characterController.camera.CameraType = Enum.CameraType.Scriptable;
				characterController.camera.CFrame = gameMap.CameraPos.GetPivot();
				characterController.camera.FieldOfView = FIELD_OF_VIEW;

				const humanoid = player.Character?.FindFirstChildOfClass("Humanoid");
				if (humanoid) {
					humanoid.AutoRotate = false;
					humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None;
				}

				const tweenInfo = new TweenInfo(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
				const tween = TweenService.Create(characterController.camera, tweenInfo, {
					CFrame: championStage.CameraPos.GetPivot(),
				});
				task.delay(2, () => tween.Play());
			}),
		];

		return () => connections.forEach((connection) => connection.Disconnect());
	}, []);

	return <>{inRound && <RoundHUD team1={teams[0]} team2={teams[1]} />}</>;
};

export default App;
