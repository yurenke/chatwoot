<script>
import { useAlert } from 'dashboard/composables';
import { mapGetters } from 'vuex';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import ContextMenu from 'dashboard/components/ui/ContextMenu.vue';
import AddCannedModal from 'dashboard/routes/dashboard/settings/canned/AddCanned.vue';
import { useSnakeCase } from 'dashboard/composables/useTransformKeys';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import { conversationUrl, frontendURL } from '../../../helper/URLHelper';
import {
  ACCOUNT_EVENTS,
  CONVERSATION_EVENTS,
} from '../../../helper/AnalyticsHelper/events';
import MenuItem from '../../../components/widgets/conversation/contextMenu/menuItem.vue';
import { useTrack } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { MESSAGE_TYPES, SENDER_TYPES, CONTENT_TYPES, ATTACHMENT_TYPES } from 'dashboard/components-next/message/constants';
import { INBOX_TYPES } from 'dashboard/helper/inbox';

export default {
  components: {
    AddCannedModal,
    MenuItem,
    ContextMenu,
    NextButton,
  },
  props: {
    message: {
      type: Object,
      required: true,
    },
    isOpen: {
      type: Boolean,
      default: false,
    },
    enabledOptions: {
      type: Object,
      default: () => ({}),
    },
    contextMenuPosition: {
      type: Object,
      default: () => ({}),
    },
    hideButton: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['open', 'close', 'replyTo', 'editMessage'],
  setup() {
    const { getPlainText } = useMessageFormatter();

    return {
      getPlainText,
    };
  },
  data() {
    return {
      isCannedResponseModalOpen: false,
      showDeleteModal: false,
      MESSAGE_TYPES,
      SENDER_TYPES,
      CONTENT_TYPES,
      ATTACHMENT_TYPES,
    };
  },
  computed: {
    ...mapGetters({
      getAccount: 'accounts/getAccount',
      currentAccountId: 'getCurrentAccountId',
      getUISettings: 'getUISettings',
      currentUserId: 'getCurrentUserID',
      currentChat: 'getSelectedChat',
      getInboxById: 'inboxes/getInbox',
    }),
    plainTextContent() {
      return this.getPlainText(this.messageContent);
    },
    conversationId() {
      return this.message.conversation_id ?? this.message.conversationId;
    },
    messageId() {
      return this.message.id;
    },
    messageContent() {
      return this.message.content;
    },
    contentAttributes() {
      return useSnakeCase(
        this.message.content_attributes ?? this.message.contentAttributes
      );
    },
    inbox() {
      return this.getInboxById(this.currentChat?.inbox_id);
    },
    isEditable() {
      console.log('--- 🚀 Telegram Edit Debug (Full Data Fetch) 🚀 ---');

      const messageId = this.message?.id;
      const conversationId = this.message?.conversation_id || this.chat?.id;
      const selectedChat = this.currentChat?.id === conversationId ? this.currentChat : (this.chat || {});
      const messages = selectedChat.messages || [];
      const fullMessage = messages.find(m => m.id === messageId) || this.message;

      console.log('--- 🕵️ Data Verification ---', {
        hasMessageType: 'message_type' in fullMessage,
        hasSenderId: 'sender_id' in fullMessage,
        actualMType: fullMessage.message_type,
        actualSId: fullMessage.sender_id
      });

      if (!fullMessage.id || !selectedChat.id) return false;

      const inbox = this.getInboxById(selectedChat.inbox_id) || {};
      const channelType = selectedChat.channel_type || inbox.channel_type;
      const isTelegram = String(channelType).toLowerCase().includes('telegram');

      if (!isTelegram) return false;

      const mType = Number(fullMessage.message_type); 
      const sType = fullMessage.sender_type;
      const sId = fullMessage.sender_id;
      const cType = fullMessage.content_type;
      const attachments = fullMessage.attachments ?? [];

      const isOutgoing = mType === MESSAGE_TYPES.OUTGOING;
      const isAgent = sType === SENDER_TYPES.USER;
      const isMine = this.currentUserId && Number(sId) === Number(this.currentUserId);
      const isPureText = (cType === CONTENT_TYPES.TEXT || !cType) && attachments.length === 0;
      const hasEditableAttachments =
        attachments.length > 0 &&
        attachments.every(att =>
          [
            ATTACHMENT_TYPES.IMAGE,
            ATTACHMENT_TYPES.AUDIO,
            ATTACHMENT_TYPES.VIDEO,
            ATTACHMENT_TYPES.FILE,
          ].includes(att.file_type || att.fileType)
        );

      const createdTime = typeof fullMessage.created_at === 'number'
        ? fullMessage.created_at * 1000
        : new Date(fullMessage.created_at).getTime();

      const isWithinTimeLimit =
        (Date.now() - createdTime) < 48 * 60 * 60 * 1000;
      console.log('--- 🛡️ Final Checks ---', { 
        isOutgoing, isAgent, isMine, isPureText, hasEditableAttachments, isWithinTimeLimit 
      });
      
      const finalResult = isOutgoing && 
                      isAgent && 
                      isMine && 
                      (isPureText || hasEditableAttachments) && 
                      isWithinTimeLimit;
  
      console.log('Final Result:', finalResult);
      return finalResult;
    }
  },
  methods: {
    async copyLinkToMessage() {
      const fullConversationURL =
        window.chatwootConfig.hostURL +
        frontendURL(
          conversationUrl({
            id: this.conversationId,
            accountId: this.currentAccountId,
          })
        );
      await copyTextToClipboard(
        `${fullConversationURL}?messageId=${this.messageId}`
      );
      useAlert(this.$t('CONVERSATION.CONTEXT_MENU.LINK_COPIED'));
      this.handleClose();
    },
    async handleCopy() {
      await copyTextToClipboard(this.plainTextContent);
      useAlert(this.$t('CONTACT_PANEL.COPY_SUCCESSFUL'));
      this.handleClose();
    },
    showCannedResponseModal() {
      useTrack(ACCOUNT_EVENTS.ADDED_TO_CANNED_RESPONSE);
      this.isCannedResponseModalOpen = true;
    },
    hideCannedResponseModal() {
      this.isCannedResponseModalOpen = false;
      this.handleClose();
    },
    handleOpen(e) {
      this.$emit('open', e);
    },
    handleClose(e) {
      this.$emit('close', e);
    },
    handleTranslate() {
      const { locale: accountLocale } = this.getAccount(this.currentAccountId);
      const agentLocale = this.getUISettings?.locale;
      const targetLanguage = agentLocale || accountLocale || 'en';
      this.$store.dispatch('translateMessage', {
        conversationId: this.conversationId,
        messageId: this.messageId,
        targetLanguage,
      });
      useTrack(CONVERSATION_EVENTS.TRANSLATE_A_MESSAGE);
      this.handleClose();
    },
    handleEdit() {
      this.handleClose();
      this.$emit('editMessage', this.message);
    },
    handleReplyTo() {
      this.$emit('replyTo', this.message);
      this.handleClose();
    },
    openDeleteModal() {
      this.handleClose();
      this.showDeleteModal = true;
    },
    async confirmDeletion() {
      try {
        await this.$store.dispatch('deleteMessage', {
          conversationId: this.conversationId,
          messageId: this.messageId,
        });
        useAlert(this.$t('CONVERSATION.SUCCESS_DELETE_MESSAGE'));
        this.handleClose();
      } catch (error) {
        useAlert(this.$t('CONVERSATION.FAIL_DELETE_MESSSAGE'));
      }
    },
    closeDeleteModal() {
      this.showDeleteModal = false;
    },
  },
};
</script>

<template>
  <div class="context-menu">
    <!-- Add To Canned Responses -->
    <woot-modal
      v-if="isCannedResponseModalOpen && enabledOptions['cannedResponse']"
      v-model:show="isCannedResponseModalOpen"
      :on-close="hideCannedResponseModal"
    >
      <AddCannedModal
        :response-content="plainTextContent"
        :on-close="hideCannedResponseModal"
      />
    </woot-modal>
    <!-- Confirm Deletion -->
    <woot-delete-modal
      v-if="showDeleteModal && enabledOptions['delete']"
      v-model:show="showDeleteModal"
      class="context-menu--delete-modal"
      :on-close="closeDeleteModal"
      :on-confirm="confirmDeletion"
      :title="$t('CONVERSATION.CONTEXT_MENU.DELETE_CONFIRMATION.TITLE')"
      :message="$t('CONVERSATION.CONTEXT_MENU.DELETE_CONFIRMATION.MESSAGE')"
      :confirm-text="$t('CONVERSATION.CONTEXT_MENU.DELETE_CONFIRMATION.DELETE')"
      :reject-text="$t('CONVERSATION.CONTEXT_MENU.DELETE_CONFIRMATION.CANCEL')"
    />
    <NextButton
      v-if="!hideButton"
      ghost
      slate
      sm
      icon="i-lucide-ellipsis-vertical"
      class="invisible group-hover/context-menu:visible"
      @click="handleOpen"
    />
    <ContextMenu
      v-if="isOpen && !isCannedResponseModalOpen"
      :x="contextMenuPosition.x"
      :y="contextMenuPosition.y"
      @close="handleClose"
    >
      <div class="menu-container">
        <MenuItem
          v-if="enabledOptions['replyTo']"
          :option="{
            icon: 'arrow-reply',
            label: $t('CONVERSATION.CONTEXT_MENU.REPLY_TO'),
          }"
          variant="icon"
          @click.stop="handleReplyTo"
        />
        <MenuItem
          v-if="enabledOptions['copy']"
          :option="{
            icon: 'clipboard',
            label: $t('CONVERSATION.CONTEXT_MENU.COPY'),
          }"
          variant="icon"
          @click.stop="handleCopy"
        />
        <MenuItem
          v-if="isEditable"
          :option="{
            icon: 'edit',
            label: $t('CONVERSATION.CONTEXT_MENU.EDIT') === 'CONVERSATION.CONTEXT_MENU.EDIT' 
                    ? '編輯' 
                    : $t('CONVERSATION.CONTEXT_MENU.EDIT'),
          }"
          variant="icon"
          @click.stop="handleEdit"
        />
        <MenuItem
          v-if="enabledOptions['translate']"
          :option="{
            icon: 'translate',
            label: $t('CONVERSATION.CONTEXT_MENU.TRANSLATE'),
          }"
          variant="icon"
          @click.stop="handleTranslate"
        />
        <hr />
        <MenuItem
          v-if="enabledOptions['copyLink']"
          :option="{
            icon: 'link',
            label: $t('CONVERSATION.CONTEXT_MENU.COPY_PERMALINK'),
          }"
          variant="icon"
          @click.stop="copyLinkToMessage"
        />
        <MenuItem
          v-if="enabledOptions['cannedResponse']"
          :option="{
            icon: 'comment-add',
            label: $t('CONVERSATION.CONTEXT_MENU.CREATE_A_CANNED_RESPONSE'),
          }"
          variant="icon"
          @click.stop="showCannedResponseModal"
        />
        <hr v-if="enabledOptions['delete']" />
        <MenuItem
          v-if="enabledOptions['delete']"
          :option="{
            icon: 'delete',
            label: $t('CONVERSATION.CONTEXT_MENU.DELETE'),
          }"
          variant="icon"
          @click.stop="openDeleteModal"
        />
      </div>
    </ContextMenu>
  </div>
</template>

<style lang="scss" scoped>
.menu-container {
  @apply p-1 bg-n-background shadow-xl rounded-md;

  hr:first-child {
    @apply hidden;
  }

  hr {
    @apply m-1 border-b border-solid border-n-strong;
  }
}

.context-menu--delete-modal {
  ::v-deep {
    .modal-container {
      @apply max-w-[30rem];

      h2 {
        @apply font-medium text-base;
      }
    }
  }
}
</style>
