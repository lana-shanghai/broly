use onchain::orderbook::interface::IOrderbook;

#[starknet::contract]
mod OrderbookMock {
    use core::byte_array::ByteArray;
    use consensus::{types::transaction::{Transaction}};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use utils::hash::Digest;
    use utu_relay::bitcoin::block::BlockHeader;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};

    const INSCRIPTION_CANCELED: i8 = -1;
    const INSCRIPTION_NULL: i8 = 0;
    const INSCRIPTION_REQUESTED: i8 = 1;
    const INSCRIPTION_LOCKED: i8 = 2;
    const INSCRIPTION_COMPLETED: i8 = 3;

    #[storage]
    struct Storage {
        // ID of the next inscription.
        new_inscription_id: u32,
        // Locks: Map inscription_id -> status.
        inscription_status: Map<u32, i8>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        RequestCreated: RequestCreated,
        RequestCanceled: RequestCanceled,
        RequestLocked: RequestLocked,
        RequestCompleted: RequestCompleted,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RequestCreated {
        #[key]
        inscription_id: u32,
        #[key]
        caller: ContractAddress,
        receiving_address: ByteArray,
        currency_fee: felt252,
        submitter_fee: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RequestCanceled {
        #[key]
        inscription_id: u32,
        currency_fee: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RequestLocked {
        #[key]
        inscription_id: u32,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RequestCompleted {
        #[key]
        inscription_id: u32,
        tx_hash: ByteArray,
    }

    #[constructor]
    fn constructor(ref self: ContractState, strk_token: ContractAddress) {
        // initialize contract
        self.initializer(:strk_token);
    }

    #[abi(embed_v0)]
    impl OrderbookMockImpl of super::IOrderbook<ContractState> {
        /// Called by a user.
        /// Inputs:
        /// - `inscription_data: ByteArray`, the data to be inscribed on Bitcoin.
        /// - `receiving_address: ByteArray`, the taproot address that will own the inscription.
        /// - `currency_fee: felt252`, 'STRK' tokens.
        /// - `submitter_fee: u256`, fee to be paid to the submitter for the inscription.
        /// Returns:
        /// - `id: felt252`, the ID of the created inscription.
        fn request_inscription(
            ref self: ContractState,
            inscription_data: ByteArray,
            receiving_address: ByteArray,
            currency_fee: felt252,
            submitter_fee: u256,
        ) -> u32 {
            let id = self.new_inscription_id.read();
            self.new_inscription_id.write(id + 1);
            self.inscription_status.write(id, INSCRIPTION_REQUESTED);
            self
                .emit(
                    RequestCreated {
                        inscription_id: id,
                        caller: get_caller_address(),
                        receiving_address: receiving_address,
                        currency_fee: currency_fee,
                        submitter_fee: submitter_fee,
                    },
                );
            id
        }

        /// Called by a user.
        /// Inputs:
        /// - `inscription_id: felt252`, the ID of the inscription the user wants to
        /// cancel.
        /// - `currency_fee: felt252`, the token that the user paid the submitter fee in.
        fn cancel_inscription(ref self: ContractState, inscription_id: u32, currency_fee: felt252) {
            let status = self.inscription_status.read(inscription_id);
            assert!(status == INSCRIPTION_REQUESTED);
            self.inscription_status.write(inscription_id, INSCRIPTION_CANCELED);
            self
                .emit(
                    RequestCanceled { inscription_id: inscription_id, currency_fee: currency_fee },
                );
        }

        /// Called by a submitter. Multiple submitters are allowed to lock the
        /// inscription simultaneously. The fee will be received only by the
        /// submitter that will actually create the inscription on Bitcoin.
        /// Assert that the inscription has not been closed yet. If there is a
        /// prior lock on the inscription, X blocks have to pass before a new
        /// lock can be created.
        /// Inputs:
        /// - `inscription_id: u32`, the ID of the inscription being locked.
        fn lock_inscription(ref self: ContractState, inscription_id: u32) {
            let status = self.inscription_status.read(inscription_id);
            assert!(status == INSCRIPTION_REQUESTED);
            self.inscription_status.write(inscription_id, INSCRIPTION_LOCKED);
            self.emit(RequestLocked { inscription_id: inscription_id });
        }

        /// Called by a submitter. The fee is transferred to the submitter if
        /// the inscription on Bitcoin has been made. The submitted hash must
        /// match the precomputed transaction hash in storage. If successful,
        /// the status of the inscription changes from 'Locked' to 'Closed'.
        /// Inputs:
        /// - `inscription_id: felt252`, the ID of the inscription being locked.
        /// - `tx_hash: ByteArray`, the hash of the transaction submitted to Bitcoin.
        fn submit_inscription(
            ref self: ContractState,
            inscription_id: u32,
            tx_hash: ByteArray,
            tx: Transaction,
            pk_script: Array<u8>,
            block_height: u64,
            block_header: BlockHeader,
            inclusion_proof: Array<(Digest, bool)>,
        ) {
            let status = self.inscription_status.read(inscription_id);
            assert!(status == INSCRIPTION_LOCKED);
            self.inscription_status.write(inscription_id, INSCRIPTION_COMPLETED);
            self.emit(RequestCompleted { inscription_id: inscription_id, tx_hash: tx_hash });
        }

        fn query_inscription(
            self: @ContractState, inscription_id: u32,
        ) -> (ContractAddress, ByteArray, u256, ByteArray) {
            return (get_contract_address(), "", 0, "");
        }

        fn query_inscription_lock(
            self: @ContractState, inscription_id: u32,
        ) -> (ContractAddress, u64) {
            return (get_contract_address(), 0);
        }
    }

    #[generate_trait]
    pub impl InternalImpl of InternalTrait {
        /// Executed once when the Orderbook contract is deployed. Used to set
        /// initial values for contract storage variables for the fee tokens.
        fn initializer(ref self: ContractState, strk_token: ContractAddress) {}
    }
}
