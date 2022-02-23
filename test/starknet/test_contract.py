import asyncio
import os
import pytest

from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet

COMPILED_CONTRACTS_DIR = os.path.join("starknet-artifacts", "contracts", "starknet")


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.get_event_loop()
    yield loop
    loop.close()


@pytest.fixture(scope="session")
async def starknet() -> Starknet:
    return await Starknet.empty()


async def load_compiled_contract_and_deploy(
    starknet: Starknet, contract_name: str
) -> StarknetContract:
    return await starknet.deploy(
        constructor_calldata=[],
        contract_def=ContractDefinition.loads(
            open(
                os.path.join(
                    COMPILED_CONTRACTS_DIR, f"{contract_name}.cairo", f"{contract_name}.json"
                )
            ).read()
        ),
    )


@pytest.fixture
async def l1_auth_mock_contract(starknet: Starknet) -> StarknetContract:
    return load_compiled_contract_and_deploy(starknet=starknet, contract_name="L1AuthMock")


@pytest.fixture
async def l2_auth_mock_contract(starknet: Starknet) -> StarknetContract:
    return load_compiled_contract_and_deploy(starknet=starknet, contract_name="L2AuthMock")


def test_fixtures(l1_auth_mock_contract: StarknetContract, l2_auth_mock_contract: StarknetContract):
    pass
