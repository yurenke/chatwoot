import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import FaqIndex from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/faq'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          redirect: to => {
            return { name: 'faq_index', params: to.params };
          },
        },
        {
          path: 'documents',
          name: 'faq_index',
          component: FaqIndex,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};