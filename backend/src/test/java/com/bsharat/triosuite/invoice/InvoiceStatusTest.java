package com.bsharat.triosuite.invoice;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

/**
 * The state machine as a pure unit test.
 *
 * <p>{@code InvoiceLifecycleIT} proves the rules hold over HTTP; this proves the table itself is
 * complete, including that no status was added later without deciding what it allows.
 */
class InvoiceStatusTest {

    @Test
    @DisplayName("only a draft is editable")
    void onlyDraftIsEditable() {
        assertThat(InvoiceStatus.DRAFT.isEditable()).isTrue();
        assertThat(InvoiceStatus.APPROVED.isEditable()).isFalse();
        assertThat(InvoiceStatus.CANCELLED.isEditable()).isFalse();
    }

    @Test
    @DisplayName("only a draft can be approved")
    void onlyDraftCanBeApproved() {
        assertThat(InvoiceStatus.DRAFT.canApprove()).isTrue();
        assertThat(InvoiceStatus.APPROVED.canApprove()).isFalse();
        assertThat(InvoiceStatus.CANCELLED.canApprove()).isFalse();
    }

    @Test
    @DisplayName("a draft or an approved invoice can be cancelled, but not a cancelled one")
    void cancellationIsTerminal() {
        assertThat(InvoiceStatus.DRAFT.canCancel()).isTrue();
        assertThat(InvoiceStatus.APPROVED.canCancel()).isTrue();
        assertThat(InvoiceStatus.CANCELLED.canCancel()).isFalse();
    }

    @ParameterizedTest
    @EnumSource(InvoiceStatus.class)
    @DisplayName("anything editable is also approvable, and nothing else is")
    void editabilityAndApprovalCoincide(InvoiceStatus status) {
        assertThat(status.isEditable()).isEqualTo(status.canApprove());
    }

    @ParameterizedTest
    @EnumSource(InvoiceStatus.class)
    @DisplayName("CANCELLED is the only status from which nothing at all is possible")
    void cancelledAllowsNothing(InvoiceStatus status) {
        boolean anythingAllowed = status.isEditable() || status.canApprove() || status.canCancel();
        assertThat(anythingAllowed).isEqualTo(status != InvoiceStatus.CANCELLED);
    }

    @Test
    @DisplayName("the lifecycle has exactly the three statuses the schema constrains")
    void statusSetIsClosed() {
        assertThat(InvoiceStatus.values())
                .containsExactly(
                        InvoiceStatus.DRAFT, InvoiceStatus.APPROVED, InvoiceStatus.CANCELLED);
    }
}
