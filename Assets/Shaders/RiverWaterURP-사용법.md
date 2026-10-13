# URP 강 표면 셰이더

Unity 2022.3 / URP 14의 기본 API를 기준으로 작성했습니다. Unity 6에서도 적용을 시도할 수 있지만, 이 환경에는 Unity Editor가 없어 셰이더 컴파일과 화면 결과는 검증하지 못했습니다.

## 적용

1. `RiverWaterURP.shader`를 프로젝트의 `Assets/Shaders`에 복사합니다.
2. 사용 중인 URP Asset에서 **Depth Texture**와 **Opaque Texture**를 켭니다. 카메라에서 이를 끄도록 재정의했다면 카메라 설정도 수정합니다. Quality마다 다른 URP Asset을 쓰면 해당 Asset도 확인합니다.
3. 새 Material을 만들고 Shader를 **Ubisworld / URP / River Water**로 선택합니다.
4. 강 표면 메시 또는 Unity Plane에 머티리얼을 적용합니다. 메시에 UV, 위쪽을 향하는 노멀, 탄젠트가 필요합니다. 강바닥과 강둑은 불투명 머티리얼로 렌더링하고, 물 표면은 강바닥보다 위에 배치합니다.
5. 노멀맵 2개의 Texture Type을 **Normal map**, Wrap Mode를 **Repeat**로 설정하고 Normal Map A/B에 넣습니다. A Tiling은 `(4, 4)`, B는 `(7, 7)`로 시작해 메시 크기에 맞게 조절합니다.
6. 가능하면 강 주변에 Reflection Probe를 배치하고 Bake합니다. 반사 환경이 없다면 Lighting의 Skybox와 환경 반사 설정을 확인합니다.

## 머티리얼 조절

- **Shallow / Deep Color**: 얕은 물과 깊은 물 색. 색상의 Alpha는 물 색이 배경을 가리는 정도입니다. 깊은 물 Alpha를 높이면 강바닥이 덜 보입니다.
- **Depth Color Distance**: 수심에 따른 색 변화 거리. 기본값 3m이며 작은 값일수록 빠르게 어두워집니다.
- **Flow A / B**: XY는 메시 UV상의 흐름 방향, Z는 초당 UV 이동량입니다. 실제 강 방향에 맞춰 UV를 펴거나 XY 방향을 바꾸세요. 서로 비슷한 방향과 다른 속도를 사용하면 강 흐름처럼 보입니다.
- **Normal Strength**: 잔물결 강도. 0.3~0.7부터 시작하세요.
- **Edge Fade**: 강둑과 물의 접촉 경계를 부드럽게 만드는 거리.
- **Foam Width / Amount / Color**: 얕은 접촉부의 거품 폭, 양, 색. 잔잔한 강은 Amount를 0.1~0.3으로 줄이세요.
- **Smoothness / Reflection Strength**: 햇빛 반짝임과 환경 반사.
- **Refraction Strength**: 강바닥 굴절 강도. 0.003~0.01을 권장합니다.

## 확인할 장면

경사진 강바닥과 물을 가로지르는 불투명 바위를 배치하세요. 물이 깊어질수록 색이 짙어지고 강바닥이 덜 보이는지, 강둑과 바위 경계가 부드러운지, 두 물결이 서로 다른 속도로 움직이는지 확인합니다. 카메라 각도를 낮췄을 때 환경 반사도 확인하세요.

## 제한

깊이는 화면의 깊이 텍스처로 계산한 카메라 시선 방향 거리이며 실제 수직 수심은 아닙니다. 수면 메시 자체의 높이는 움직이지 않습니다. 거품은 접촉 깊이와 노멀맵 기반의 간단한 표현으로, 유체 시뮬레이션이 아닙니다. Opaque Texture에는 다른 투명 오브젝트가 포함되지 않으므로 여러 겹의 물, 수중 투명 오브젝트, 수중 카메라에는 별도 처리가 필요합니다. 모바일에서는 Depth/Opaque Texture 비용을 실제 기기에서 확인하세요. 이 셰이더는 메인 광원과 환경 반사를 사용하며 추가 광원은 별도로 합산하지 않습니다.
