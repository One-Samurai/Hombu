module honbu::admin;

public struct AdminCap has key, store {
    id: UID,
}

fun init(ctx: &mut TxContext) {
    let cap = AdminCap { id: object::new(ctx) };
    transfer::public_transfer(cap, ctx.sender());
}

#[test_only]
public fun mint_for_testing(ctx: &mut TxContext): AdminCap {
    AdminCap { id: object::new(ctx) }
}
