import { useFlameworkDependency } from "@rbxts/flamework-react-utils";
import React, { useEffect, useState } from "@rbxts/react";
import { CharacterController } from "client/controllers";
import { ResourceCount } from "client/ui/elements/round";

const ResourceDisplay = (): React.Element => {
	const characterController = useFlameworkDependency<CharacterController>();
	const [blockCount, setBlockCount] = useState(characterController.blockCount);
	const [projectileCount, setProjectileCount] = useState(characterController.projectileCount);

	useEffect(() => {
		const connections: Array<RBXScriptConnection> = [
			characterController.BlockCountChanged.Connect((count) => setBlockCount(count)),
			characterController.ProjectileCountChanged.Connect((count) => setProjectileCount(count)),
		];
		return () => connections.forEach((connection) => connection.Disconnect());
	}, []);

	return (
		<frame
			AnchorPoint={new Vector2(1, 1)}
			BackgroundTransparency={1}
			Position={UDim2.fromScale(1, 1)}
			Size={UDim2.fromScale(0, 1)}
		>
			<ResourceCount
				count={projectileCount}
				resourcePrefab={characterController.projectilePrefab}
				teamColor={characterController.team.TeamColor}
			/>
			<ResourceCount
				count={blockCount}
				resourcePrefab={characterController.blockPrefab}
				teamColor={characterController.team.TeamColor}
				viewportOffset={new Vector3(-3, 3, -3)}
			/>
			<uiaspectratioconstraint
				AspectRatio={2.5}
				AspectType={Enum.AspectType.ScaleWithParentSize}
				DominantAxis={Enum.DominantAxis.Height}
			/>
			<uilistlayout
				Padding={new UDim(0.1, 0)}
				FillDirection={Enum.FillDirection.Horizontal}
				HorizontalAlignment={Enum.HorizontalAlignment.Right}
			/>
		</frame>
	);
};

export default ResourceDisplay;
